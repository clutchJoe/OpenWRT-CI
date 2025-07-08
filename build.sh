#!/usr/bin/env bash

echo $WRT_CONFIG
export WRT_CONFIG="IPQ60XX-WIFI-YES"
export WRT_THEME="argon"
export WRT_NAME="OWRT"
export WRT_SSID="OWRT"
export WRT_WORD="12345678"
export WRT_IP="192.168.10.1"
export WRT_PW="无"
export WRT_REPO="https://github.com/VIKINGYFY/immortalwrt.git"
export WRT_BRANCH="main"
export WRT_SOURCE="VIKINGYFY/immortalwrt"
export WRT_PACKAGE=""
export WRT_TEST="false"

export GITHUB_REPOSITORY="VIKINGYFY/immortalwrt"
export GITHUB_WORKSPACE=$(pwd)
echo $GITHUB_WORKSPACE
echo $WRT_TEMP

initValues() {
  export WRT_DATE=$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")
  export WRT_MARK=$(echo $GITHUB_REPOSITORY | cut -d '/' -f 1)
  export WRT_VER=$(echo $WRT_REPO | cut -d '/' -f 4)'-'$WRT_BRANCH
  echo $WRT_VER
  export WRT_TARGET=$(grep -m 1 -oP '^CONFIG_TARGET_\K[\w]+(?=\=y)' ./Config/$WRT_CONFIG.txt | tr '[:lower:]' '[:upper:]')
  export WRT_KVER=none
  export WRT_LIST=none

  # export WRT_CI=$WRT_CI
  [[ -z $WRT_ARCH ]] && {
    export WRT_ARCH=$(sed -n 's/.*_DEVICE_\(.*\)_DEVICE_.*/\1/p' $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt | head -n 1)
    export WRT_ARCH=$WRT_ARCH
  }
  echo "$WRT_REPO/$WRT_BRANCH" > "$GITHUB_WORKSPACE/repo_flag"
  echo $WRT_ARCH
}

cloneCode() {
  git clone --depth=1 --single-branch --branch $WRT_BRANCH $WRT_REPO ./wrt/
  cd ./wrt/ && export WRT_HASH=$(git log -1 --pretty=format:'%h')
  # git clone --depth=1 --single-branch --branch $WRT_BRANCH $WRT_REPO
  # export WRT_HASH=$(git log -1 --pretty=format:'%h')

  # GitHub Action 移除国内下载源
  PROJECT_MIRRORS_FILE="./scripts/projectsmirrors.json"
  if [ -f "$PROJECT_MIRRORS_FILE" ]; then
    sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
  fi
  cd ..
}

checkScript() {
  find ./ -maxdepth 3 -type f -iregex ".*\(txt\|sh\)$" -exec dos2unix {} \; -exec chmod +x {} \;
}

updateFeeds() {
  # cd ./wrt/

  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

customPackage() {
  # cd ./wrt/package/

  $GITHUB_WORKSPACE/Scripts/Packages.sh
  $GITHUB_WORKSPACE/Scripts/Handles.sh
}

customSettings() {
  # cd ./wrt/

  if [[ "${WRT_CONFIG,,}" == *"test"* ]]; then
    cat $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt >> .config
  else
    cat $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt $GITHUB_WORKSPACE/Config/GENERAL.txt >> .config
  fi

  if [[ "$WRT_CONFIG" == *"IPQ60XX"* ]] || [[ "$WRT_CONFIG" == *"ipq60xx"* ]]; then
    echo "检测到 IPQ60XX"
    # start, copy from https://github.com/clutchJoe/OpenWRT-dae/blob/4250d422896f8d9d9c0426731f8dd4686e614924/Scripts/function.sh#L118C3-L123C113
    image_file='./target/linux/qualcommax/image/ipq60xx.mk'
    sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/redmi_ax5-jdcloud/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
    sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" $image_file
    # end
  else
    echo "未检测到 IPQ60XX，跳过"
  fi

  $GITHUB_WORKSPACE/Scripts/Settings.sh

  make defconfig -j$(nproc) && make clean -j$(nproc)
}

downPackages() {
  # cd ./wrt/

  make download -j$(nproc)
}

compileFiemware() {
  # cd ./wrt/

  make -j$(nproc) || make -j$(nproc) V=s
}

packageFirmware() {
  # cd ./wrt/ && mkdir ./upload/
  mkdir ./upload/

  cp -f ./.config ./upload/Config-"$WRT_CONFIG"-"$WRT_INFO"-"$WRT_BRANCH"-"$WRT_DATE".txt

  # if [[ $WRT_TEST != 'true' ]]; then
  #   echo "WRT_KVER=$(find ./bin/targets/ -type f -name "*.manifest" -exec grep -oP '^kernel - \K[\d\.]+' {} \;)" >> $GITHUB_ENV
  #   echo "WRT_LIST=$(find ./bin/targets/ -type f -name "*.manifest" -exec grep -oP '^luci-(app|theme)[^ ]*' {} \; | tr '\n' ' ')" >> $GITHUB_ENV

  #   find ./bin/targets/ -iregex ".*\(buildinfo\|json\|sha256sums\|packages\)$" -exec rm -rf {} +

  #   for FILE in $(find ./bin/targets/ -type f -iname "*$WRT_TARGET*") ; do
  #     EXT=$(basename $FILE | cut -d '.' -f 2-)
  #     NAME=$(basename $FILE | cut -d '.' -f 1 | grep -io "\($WRT_TARGET\).*")
  #     NEW_FILE="$WRT_INFO"-"$WRT_BRANCH"-"$NAME"-"$WRT_DATE"."$EXT"
  #     mv -f $FILE ./upload/$NEW_FILE
  #   done

  #   find ./bin/targets/ -type f -exec mv -f {} ./upload/ \;

  #   make clean -j$(nproc)
  # fi

  make clean -j$(nproc)
}

t1() {
  cd ./Config
  pwd
}

t2() {
  pwd
}

main() {
  initValues
  # cd ./wrt/
  # cloneCode
  # cd ..
  checkScript
  cd ./wrt/
  updateFeeds
  cd ./package/
  customPackage
  cd ..
  customSettings
  downPackages
  compileFiemware
  packageFirmware
}

main
