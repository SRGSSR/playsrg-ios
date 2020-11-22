#!/bin/bash -e -x

# Requirements:
# brew install imagemagick ghostscript

PYTHON_NIGHTLIES_TAG="---->"
PYTHON_NIGHTLIES_CLOSING_TAG="***********************"

if [ "${CONFIGURATION}" == "AppStore" ]; then
    exit 0
fi

export PATH="${PATH}:/usr/local/bin:/opt/local/bin"

BUSINESS_UNIT=`echo ${PRODUCT_NAME} | sed 's/Play //g'`
SOURCE_IOS_RESOURCES_PATH="${SRCROOT}/Application/Resources/Apps/Play ${BUSINESS_UNIT}/${BUSINESS_UNIT}Resources.xcassets"
SOURCE_IOS_APPICON_PATH="${SOURCE_IOS_RESOURCES_PATH}/AppIcon.appiconset"
DUPLICATE_IOS_APPICON_PATH="${SOURCE_IOS_RESOURCES_PATH}/OriginalAppIcon.appiconset"
SOURCE_TVOS_RESOURCES_PATH="${SRCROOT}/TV Application/Resources/Play ${BUSINESS_UNIT}/${BUSINESS_UNIT}Assets.xcassets"
SOURCE_TVOS_APPICON_PATH="${SOURCE_TVOS_RESOURCES_PATH}/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Layer 4.imagestacklayer/Content.imageset"
DUPLICATE_TVOS_APPICON_PATH="${SOURCE_TVOS_RESOURCES_PATH}/OriginalAppIcon.appiconset"

echo $PYTHON_NIGHTLIES_TAG "Restore original iOS app icons..."

if [ ! -e "${DUPLICATE_IOS_APPICON_PATH}" ]; then
    echo $PYTHON_NIGHTLIES_TAG "Original iOS app icons not found."
    exit 0
fi

rm -fR "${SOURCE_IOS_APPICON_PATH}"
mv "${DUPLICATE_IOS_APPICON_PATH}" "${SOURCE_IOS_APPICON_PATH}"

echo $PYTHON_NIGHTLIES_TAG "Original iOS app icons Restored."

echo $PYTHON_NIGHTLIES_TAG "Restore original tvOS app icons..."

if [ ! -e "${DUPLICATE_TVOS_APPICON_PATH}" ]; then
    echo $PYTHON_NIGHTLIES_TAG "Original tvOS app icons not found."
    exit 0
fi

rm -fR "${SOURCE_TVOS_APPICON_PATH}"
mv "${DUPLICATE_TVOS_APPICON_PATH}" "${SOURCE_TVOS_APPICON_PATH}"

echo $PYTHON_NIGHTLIES_TAG "Original tvOS app icons Restored."

exit 0
