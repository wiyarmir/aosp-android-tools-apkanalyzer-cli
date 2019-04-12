FROM xqdocker/ubuntu-openjdk:8 AS build
RUN apt-get update && apt-get install -y python git-core zip curl unzip
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo \
  && chmod a+x /usr/local/bin/repo
RUN mkdir studio-master-dev &&\
  cd studio-master-dev &&\
  repo init -u https://android.googlesource.com/platform/manifest -b studio-master-dev &&\
  repo sync -c -j4 -q
ADD *.patch /
RUN cd /studio-master-dev/tools/base &&\
  git apply ../../../skip-blaze.patch &&\
  git apply ../../../skip-license.patch
RUN mkdir -p /studio-master-dev/prebuilts/studio/sdk/linux/
RUN cd /studio-master-dev/tools &&\
  base/bazel/bazel run //tools/base/bazel/sdk:dev-sdk-updater -- \
  --platform linux \
  --package-file /studio-master-dev/tools/base/bazel/sdk/remote-sdk-packages \
  --dest /studio-master-dev/prebuilts/studio/sdk/
RUN cd /studio-master-dev/tools/base &&\
  git apply ../../../fix-apkanalyzer.patch
RUN cd /studio-master-dev/tools &&\
  ./gradlew :base:apkparser:apkanalyzer-cli:assemble

FROM xqdocker/ubuntu-openjdk:8 AS sdk
ARG ANDROID_SDK_VERSION=4333796
ENV ANDROID_HOME /opt/android-sdk
ADD accept-licenses.sh .
RUN apt-get update && apt-get install -y \
git-core \
zip \
curl \
unzip
RUN mkdir -p ${ANDROID_HOME} && cd ${ANDROID_HOME} && \
    curl -o tools-linux.zip https://dl.google.com/android/repository/sdk-tools-linux-${ANDROID_SDK_VERSION}.zip && \
    unzip tools-linux.zip && \
    rm tools-linux.zip && \
    chmod +x /accept-licenses.sh && \
    /accept-licenses.sh $ANDROID_HOME && \
    ${ANDROID_HOME}/tools/bin/sdkmanager "build-tools;28.0.3"

FROM xqdocker/ubuntu-openjdk:8 AS run
COPY --from=sdk /opt/android-sdk/ /opt/android-sdk/
COPY --from=build /studio-master-dev/out/build/base/apkparser/apkanalyzer-cli/build/libs/apkanalyzer-cli-26.3.0-dev-all.jar /

ENTRYPOINT [ "java", "-Dcom.android.sdklib.toolsdir=/opt/android-sdk/tools", "-jar", "/apkanalyzer-cli-26.3.0-dev-all.jar" ]
