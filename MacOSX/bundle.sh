#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/env-path.sh

APP_VERSION=0
BUILD_TIME=$(date +"%y-%m-%dT%H:%M:%S")
BUILD_HASH_KEY=0


function buildIcon {
    rm -rf $BUILD_BIN_DIR/$APP_NAME.iconset
    mkdir $BUILD_BIN_DIR/$APP_NAME.iconset
    sips -z 16 16     $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_16x16.png
    sips -z 32 32     $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_16x16@2x.png
    sips -z 32 32     $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_32x32.png
    sips -z 64 64     $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_32x32@2x.png
    sips -z 128 128   $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_128x128.png
    sips -z 256 256   $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_128x128@2x.png
    sips -z 256 256   $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_256x256.png
    sips -z 512 512   $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_256x256@2x.png
    sips -z 512 512   $SRC_RESOURCES_DIR/$APP_NAME.png --out $BUILD_BIN_DIR/$APP_NAME.iconset/icon_512x512.png
    cp -v            $SRC_RESOURCES_DIR/$APP_NAME.png       $BUILD_BIN_DIR/$APP_NAME.iconset/icon_512x512@2x.png
    iconutil -c icns -o $BUILD_BIN_DIR/$APP_NAME.icns $BUILD_BIN_DIR/$APP_NAME.iconset
    # rm -r $BUILD_BIN_DIR/$APP_NAME.iconset
}


function buildAppStructure {
    # structure bundle
    # QmapShack.app/
    #   Contents/
    #      Info.plist
    #      MacOS/
    #         QMapShack
    #      Resources/
    #         QMapShack.icns
    #      Frameworks/
    #         <libs>
    #      PlugIns
    #         <libs>
    
    rm -rf $BUILD_BUNDLE_DIR
    mkdir $BUILD_BUNDLE_DIR
    
    # predefined data
    cp -v -R $SRC_RESOURCES_DIR/Contents $BUILD_BUNDLE_DIR
    
    # new icon, if one has been created (otherwise the one from predefined data
    if [ -f "$BUILD_BIN_DIR/$APP_NAME.icns" ]; then
        cp -v $BUILD_BIN_DIR/$APP_NAME.icns $BUILD_BUNDLE_RES_DIR/
    fi
    
    # binary
    mkdir $BUILD_BUNDLE_APP_DIR
    cp -v $BUILD_BIN_DIR/qmapshack  $BUILD_BUNDLE_APP_DIR/$APP_NAME
    
    mkdir $BUILD_BUNDLE_RES_QM_DIR
    mkdir $BUILD_BUNDLE_RES_GDAL_DIR
    mkdir $BUILD_BUNDLE_RES_PROJ_DIR
    mkdir $BUILD_BUNDLE_RES_ROUTINO_DIR
    mkdir $BUILD_BUNDLE_RES_BIN_DIR
    cp -v $BUILD_DIR/src/*.qm $BUILD_BUNDLE_RES_QM_DIR
}

function qtDeploy {
    # -no-strip 
    $QT_DIR/bin/macdeployqt $BUILD_BUNDLE_DIR -always-overwrite -verbose=3
}

function printLinkingApp {
    printLinking $BUILD_BUNDLE_APP_FILE

    for F in `find $BUILD_BUNDLE_FRW_DIR -type f -type f \( -iname "*.dylib" -o -iname "*.so" \)`    
    do
        printLinking $F
    done
    
    for F in `find $BUILD_BUNDLE_FRW_DIR/Qt*.framework/Versions/5 -type f -maxdepth 1` 
    do
        printLinking $F
    done

    for F in `find $BUILD_BUNDLE_PLUGIN_DIR -type f -type f \( -iname "*.dylib" -o -iname "*.so" \)` 
    do
        printLinking $F
    done
    
    checkLibraries $BUILD_BUNDLE_APP_FILE

    for F in `find $BUILD_BUNDLE_FRW_DIR -type f -type f \( -iname "*.dylib" -o -iname "*.so" \)`    
    do
        checkLibraries $F
    done
    
    for F in `find $BUILD_BUNDLE_FRW_DIR/Qt*.framework/Versions/5 -type f -maxdepth 1` 
    do
        checkLibraries $F
    done

    for F in `find $BUILD_BUNDLE_PLUGIN_DIR -type f -type f \( -iname "*.dylib" -o -iname "*.so" \)` 
    do
        checkLibraries $F
    done   
}

function adjustLinking {
 
    for F in `find $BUILD_BUNDLE_PLUGIN_DIR -type f -type f \( -iname "*.dylib" -o -iname "*.so" \)` 
    do 
        adjustLinkQt $F "libq"
    done

    for F in `find $BUILD_BUNDLE_FRW_DIR/Qt*.framework/Versions/5 -type f -maxdepth 1` 
    do 
        adjustLinkQt $F "Qt"
        adjustLinkQt $F "libdbus"
    done

    for F in `find $BUILD_BUNDLE_FRW_DIR -type f -type f \( -iname "*.dylib" -o -iname "*.so" \)` 
    do 
        adjustLinkQt $F "Qt"
        adjustLinkQt $F "libroutino"
        adjustLinkQt $F "libdbus"
    done

    adjustLinkQt $BUILD_BUNDLE_APP_FILE "Qt"
    adjustLinkQt $BUILD_BUNDLE_APP_FILE "libroutino"
}

function adjustLinkQt {
    F=$1 # file
    L=$2 # search condition
    FREL=${F##*/}

    for P in `otool -L $F | awk '{print $1}'`
    do
        #  replace double slashes
        if [[ "$P" == *//* ]]; then 
            PSLASH=$(echo $P | sed 's,//,/,g')
            sudo install_name_tool -change $P $PSLASH $F
        fi

        LIB=${P##*/}
        LIB=${LIB%%:}
        PREL="@executable_path/../Frameworks/$LIB"

        if [[ "$P" == *".framework"* ]]; then
            LIB_VERSION=Versions/5
            LIB=$LIB.framework/$LIB_VERSION/$LIB
            PREL="@executable_path/../Frameworks/$LIB"
        elif [[ "$P" == *"plugins"* ]]; then
            # subdirectory for PlugIns
            LIB=${P##*plugins/} # remove prepart
            PREL="@executable_path/../PlugIns/$LIB"
        fi

#echo "F    = $F"
#echo "P    = $P"
#echo "LIB  = $LIB"
#echo "FREL = $FREL"
#echo "PREL = $PREL"
#echo "L    = $L"
#echo "-----"
		if [[ "$LIB" == *"$FREL" ]]; then
            echo "name_tool: $FREL >> $PREL ($P)"
            sudo install_name_tool -id $PREL $F
        elif [[ "$P" == *$L* ]]; then
            echo "name_tool: $FREL > $PREL ($P)"
            sudo install_name_tool -change $P $PREL $F
        fi
    done
}


function checkLibraries {
	F=$1 # file
	DIR=${BUILD_BUNDLE_APP_FILE%/*}
	
	for P in `otool -L $F | awk '{print $1}'`
    do
    	if [[ "$P" == "@executable_path"* ]]; then
    		FREL=${P##@executable_path}
    		LIB=${DIR}${FREL}
    		#echo "LIB = $LIB"
    		if [ ! -e $LIB ]; then
    			echo "referenced library not bundled: $P"
    		fi
    	fi
    	if [[ "$P" == "/"* && "$P" != "/System/Library/"* && "$P" != "/usr/lib/"* && "$P" != *":" ]]; then
    		echo "external library: $P"
    	fi
    done
}

function copyAdditionalLibraries {
    cp -v    $ROUTINO_LIB_LIB_DIR/libroutino.so $BUILD_BUNDLE_FRW_DIR
    cp -v    $QUAZIP_LIB_LIB_DIR/libquazip.1.dylib $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtSensors.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtPositioning.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtMultimediaWidgets.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtMultimedia.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtWebKitWidgets.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtOpenGL.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtQuick.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtQml.framework $BUILD_BUNDLE_FRW_DIR
    cp -v -R $QT_DIR/lib/QtWebChannel.framework $BUILD_BUNDLE_FRW_DIR
    # TODO remove QT Bus, is only for linux needed
    #cp -v -R $QT_DIR/lib/QtDBus.framework $BUILD_BUNDLE_FRW_DIR
}

function copyExternalFiles {
    cp -v $QT_DIR/translations/*_cs.qm $BUILD_BUNDLE_RES_QM_DIR
    cp -v $QT_DIR/translations/*_de.qm $BUILD_BUNDLE_RES_QM_DIR
    cp -v $QT_DIR/translations/*_en.qm $BUILD_BUNDLE_RES_QM_DIR
    cp -v $QT_DIR/translations/*_es.qm $BUILD_BUNDLE_RES_QM_DIR
    cp -v $QT_DIR/translations/*_fr.qm $BUILD_BUNDLE_RES_QM_DIR
    cp -v $QT_DIR/translations/*_nl.qm $BUILD_BUNDLE_RES_QM_DIR

    cp -v $GDAL_DIR/share/gdal/* $BUILD_BUNDLE_RES_GDAL_DIR
    cp -v $PROJ_DIR/share/proj/* $BUILD_BUNDLE_RES_PROJ_DIR
    
    cp -v $ROUTINO_LIB_XML_DIR/profiles.xml $BUILD_BUNDLE_RES_ROUTINO_DIR
    cp -v $ROUTINO_LIB_XML_DIR/translations.xml $BUILD_BUNDLE_RES_ROUTINO_DIR
    cp -v $ROUTINO_LIB_XML_DIR/tagging.xml $BUILD_BUNDLE_RES_ROUTINO_DIR
}


function adjustLinkingExtTools {
    for F in `find $BUILD_BUNDLE_RES_BIN_DIR -type f ! \( -name "*.py" \)`
    do
        adjustLinkQt $F "/usr/local/opt/"
        adjustLinkQt $F "/usr/local/Cellar/"
        adjustLinkQt $F "/usr/local/lib/"
    done
}


function printLinkingExtTools {
    for F in `find $BUILD_BUNDLE_RES_BIN_DIR -type f ! \( -name "*.py" \)`
    do
        printLinking $F
    done
}


function copyExtTools {
    # at least gdalbuildvrt is used
    cp -v $GDAL_DIR/bin/*                       $BUILD_BUNDLE_RES_BIN_DIR
    cp -v $PROJ_DIR/bin/proj                    $BUILD_BUNDLE_RES_BIN_DIR
    cp -v $ROUTINO_LIB_LIB_DIR/planetsplitter   $BUILD_BUNDLE_RES_BIN_DIR
}


function printLinking {
    echo "--------------------"
    echo "otool $1"
    otool -L $1
    echo "--------------------"
}

function archiveBundle {
    ARCHIVE=$(printf "%s/%s-MacOSX_%s.tar.gz" "$BUILD_RELEASE_DIR" "$APP_NAME" "$APP_VERSION")
    echo $ARCHIVE
    rm $ARCHIVE

    BUILD_RELEASE_REL_DIR=${BUILD_RELEASE_DIR##*/}
    BUILD_RELEASE_QMAPTOOL_DIR="../../qmaptool-default/$BUILD_RELEASE_REL_DIR"

    cd $BUILD_RELEASE_DIR
    rm -rf $APP_BUNDLE_QMAPTOOL
    if [ -d $BUILD_RELEASE_QMAPTOOL_DIR ]; then
        cp -v -R $BUILD_RELEASE_QMAPTOOL_DIR/$APP_BUNDLE_QMAPTOOL $BUILD_RELEASE_DIR/
        tar -zcvf $ARCHIVE $APP_BUNDLE $APP_BUNDLE_QMAPTOOL
    else
        tar -zcvf $ARCHIVE $APP_BUNDLE
    fi
    cd ..
}


function extractVersion {
    # Version CMakeList.txt
    # set(APPLICATION_VERSION_MAJOR "1")
    # set(APPLICATION_VERSION_MINOR "3")
    # set(APPLICATION_VERSION_PATCH "0.libroutino")
    
    MAJOR_VERSION=$(sed -n 's/.*APPLICATION_VERSION_MAJOR.*\"\(.*\)\".*/\1/p' $QMS_SRC_DIR/CMakeLists.txt)
    MINOR_VERSION=$(sed -n 's/.*APPLICATION_VERSION_MINOR.*\"\(.*\)\".*/\1/p' $QMS_SRC_DIR/CMakeLists.txt)
    PATCH_VERSION=$(sed -n 's/.*APPLICATION_VERSION_PATCH.*\"\(.*\)\".*/\1/p' $QMS_SRC_DIR/CMakeLists.txt)
    echo "$MAJOR_VERSION $MINOR_VERSION $PATCH_VERSION"
    APP_VERSION="$MAJOR_VERSION.$MINOR_VERSION.$PATCH_VERSION"
}

function readRevisionHash {
    cd $QMS_SRC_DIR
    BUILD_HASH_KEY=$(hg --debug id -i)
    
    if [[ "$BUILD_HASH_KEY" == *"+"* ]]; then
        read -p "BEWARE - There are uncommited chagnes..."
    fi
}


function updateInfoPlist {
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$BUILD_BUNDLE_CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION"            "$BUILD_BUNDLE_CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :BuildHashKey $BUILD_HASH_KEY"            "$BUILD_BUNDLE_CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :BuildTime $BUILD_TIME"                   "$BUILD_BUNDLE_CONTENTS_DIR/Info.plist"
}


if [[ "$1" == "icon" ]]; then
    buildIcon
fi
if [[ "$1" == "bundle" ]]; then
    echo "---extract version -----------------"
    extractVersion
    readRevisionHash
    echo "---build bundle --------------------"
    buildAppStructure
    echo "---replace version string ----------"
    updateInfoPlist
    echo "---qt deploy tool ------------------"
    qtDeploy
    echo "---copy libraries ------------------"
    copyAdditionalLibraries
    echo "---copy external files -------------"
    copyExternalFiles
    echo "---adjust linking ------------------"
    adjustLinking
    echo "---external tools ------------------"
    copyExtTools
    adjustLinkingExtTools
    printLinkingExtTools
    echo "------------------------------------"
    # chmod a+x $BUILD_BUNDLE_DIR/Contents/Frameworks/*
fi
if [[ "$1" == "info" ]]; then
    printLinkingApp
fi
if [[ "$1" == "info-before" ]]; then
    printLinking $BUILD_RELEASE_DIR/$APP_NAME
    printLinking $LIB_ROUTINO_LIB_DIR/libroutino.so
fi
if [[ "$1" == "archive" ]]; then
    extractVersion
    archiveBundle
fi
