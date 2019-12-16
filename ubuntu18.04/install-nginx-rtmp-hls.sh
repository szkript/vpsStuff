sudo apt install curl gnupg2 ca-certificates lsb-release
echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -

sudo apt update
NGINX_VERSION=$(apt show nginx | grep "^Version" | cut -d " " -f 2 | cut -d "-" -f 1)
# take note of the nginx version in the "stable" release. e.g. 1.14.2
echo NGINX version $NGINX_VERSION
wget https://hg.nginx.org/pkg-oss/raw-file/default/build_module.sh
chmod a+x build_module.sh

# NGINX RTMP module (with live HLS support)
./build_module.sh -v $NGINX_VERSION https://github.com/sergey-dryabzhinsky/nginx-rtmp-module.git

# create local repository
sudo mkdir /opt/deb
sudo cp ~/debuild/nginx-*/debian/debuild-module-rtmp/nginx-module-rtmp_*.deb /opt/deb

# nginx VOD HLS
./build_module.sh -v $NGINX_VERSION https://github.com/kaltura/nginx-vod-module.git
sudo cp ~/debuild/nginx-*/debian/debuild-module-vod/nginx-module-vod_*.deb /opt/deb

echo "deb [trusted=yes] file:/opt deb/" | sudo tee /etc/apt/sources.list.d/local.list
sudo bash -c "cd /opt && dpkg-scanpackages deb | gzip > deb/Packages.gz"
sudo apt update
sudo apt install nginx-module-rtmp nginx-module-vod


## for live RTMP with HLS check out
# - https://gist.github.com/afriza/ca7f41ccd0a358b45cf732532f977435/b9f3d918daa9e94313710b8a6b8abbc5e8b59687
## references:
# - https://www.nginx.com/blog/creating-installable-packages-dynamic-modules/
# - http://nginx.org/en/linux_packages.html#Ubuntu
# - https://docs.peer5.com/guides/setting-up-hls-live-streaming-server-using-nginx/
# - https://harry.web.id/2018/11/18/ubuntu-18-04-compile-nginx-rtmp-vod-hls/