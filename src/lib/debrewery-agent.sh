#!/usr/bin/env bash

while getopts "d:a:u:r:m:" opts; do
    case $opts in
        d)
            DISTRO=$OPTARG
            ;;
        a)
            ARCH=$OPTARG
            ;;
        u)
            URL=$OPTARG
            ;;
        r)
            REPO=$OPTARG
            ;;
        m)
            COMMITMESSAGE=$OPTARG
            ;;
    esac
done

BUILDHOST=`echo $URL | cut -f 1 -d '/'`

echo -e '\e[0;32m'$DISTRO'/'$ARCH'\e[0m'
cd  /opt/debrewery
rm *.deb *.?z *.build *.upload *.changes *.dsc
if [ -d $REPO ]; then
    cd $REPO
    unset GIT_DIR
    git reset --hard
    git pull
    git submodule update --recursive
else
    git clone --recursive "/opt/repo/"$REPO".git" && cd $REPO
fi
debclean > /dev/null
source ./debian/package.sh
if echo $FLAVOURS | grep -oq $DISTRO || [[ $FLAVOURS = 'any' ]]; then
    if [ -f ./autogen.sh ]; then
        ./autogen.sh
    fi
    dch --preserve --newversion `dpkg-parsechangelog | grep Version | cut -f 2 -d ' '`"+"$DISTRO ""
    dch --preserve -D $DISTRO --force-distribution ""
    program_version=`dpkg-parsechangelog | grep Version | cut -f 2 -d ' ' | cut -f 1 -d '-'`
    echo -e "\e[0;31m$NAME_$program_version\e[0m"
    dh_make --createorig -s -y -p $NAME"_"$program_version
    if debuild -us -uc -eDEB_BUILD_OPTIONS="parallel=32" > /tmp/debuild.log 2>&1; then
        echo -e '\e[0;34mbuild succeeded\e[0m'
        lintian_errors=$(more +/'running lintian' /tmp/debuild.log | grep 'E:' | wc -l)
        lintian_warnings=$(more +/'running lintian' /tmp/debuild.log | grep 'W:' | wc -l)
    else
        echo -e '\e[0;31mbuild failed'
        tail -n 15 /tmp/debuild.log
        echo -e '\e[0m'
    fi
    dupload --nomail /opt/debrewery/*.changes
fi
