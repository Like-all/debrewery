#!/usr/bin/env bash

while getopts "d:a:e:r:m:" opts; do
    case $opts in
        d)
            DISTRO=$OPTARG
            ;;
        a)
            ARCH=$OPTARG
            ;;
        e)
            BUILD_ENVIRONMENT=$OPTARG
            ;;
        r)
            REPO=$OPTARG
            ;;
        m)
            COMMITMESSAGE=$OPTARG
            ;;
    esac
done

export LANG='C'
FLAVOURS='any'

echo -e '\e[0;32m'$DISTRO'/'$ARCH'\e[0m'
cd  /opt/debrewery
rm *.deb *.?z *.build *.upload *.changes *.dsc
if [ -d $REPO ]; then
    cd $REPO
    unset GIT_DIR
    git reset --hard
    git submodule foreach --recursive git reset --hard
    git pull
    git submodule update --recursive
else
    git clone --recursive "/opt/repo/"$REPO".git" && cd $REPO
fi
debclean > /dev/null
source ./debian/package.sh
case $BUILD_ENVIRONMENT in
    'testing')
        FLAVOURS=$TESTING_FLAVOURS
        ;;
    'production')
        FLAVOURS=$PRODUCTION_FLAVOURS
        ;;
esac
if echo $FLAVOURS | grep -oq $DISTRO || [[ $FLAVOURS = 'any' ]]; then
    mk-build-deps --install ./debian/control
    dch --preserve --newversion `dpkg-parsechangelog | grep Version | cut -f 2 -d ' '`"+"$DISTRO ""
    dch --preserve -D $DISTRO --force-distribution ""
    program_version=`dpkg-parsechangelog | grep Version | cut -f 2 -d ' ' | cut -f 1 -d '-'`
    echo -e "\e[0;31m$NAME_$program_version\e[0m"
    dh_make --createorig -s -y -p $NAME"_"$program_version
    if debuild -eDEB_BUILD_OPTIONS="parallel=32" -sa > /tmp/debuild.log 2>&1; then
        echo -e '\e[0;34mbuild succeeded\e[0m'
        lintian_errors=$(more +/'running lintian' /tmp/debuild.log | grep 'E:' | wc -l)
        lintian_warnings=$(more +/'running lintian' /tmp/debuild.log | grep 'W:' | wc -l)
        echo "X-Lintian-Errors: $lintian_errors" >> /opt/debrewery/*.changes
        echo "X-Lintian-Warnings: $lintian_warnings" >> /opt/debrewery/*.changes
        dupload --nomail --to $BUILD_ENVIRONMENT /opt/debrewery/*.changes
    else
        echo -e '\e[0;31mbuild failed'
        tail -n 15 /tmp/debuild.log
        echo -e '\e[0m'
    fi
    log=`curl -s -F 'f:1=@/tmp/debuild.log' ix.io`
    echo -e '\e[0;32mLog: \e[0;34m'$log'\e[0m'
fi
