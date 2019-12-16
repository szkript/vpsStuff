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

cat > /etc/nginx/nginx.conf<<EOL
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

load_module modules/ngx_rtmp_module.so;
load_module modules/ngx_http_vod_module.so;

events {
    worker_connections  1024;
}

rtmp_auto_push on;
rtmp {
    server {
        listen 1935;
        chunk_size 4000;

        play_time_fix off;
        interleave on;
        publish_time_fix on;

        application live {
            live on;
            exec ffmpeg -i rtmp://$PUBLIC_IPV4/$app/$name -vcodec libx264 -vprofile
            baseline -x264opts keyint=40 -acodec aac -strict -2 -f flv rtmp://$PUBLIC_IPV4/hls/$name;
            # Turn on HLS
            hls on;
            hls_path /tmp/hls;
            hls_fragment 3;
            hls_playlist_length 60;
        }
    }
}

http {
    sendfile off;
    tcp_nopush on;
    aio on;
    directio 512;
    default_type application/octet-stream;

    server {
        listen 80;

        location /hls {
            # Disable cache
            add_header 'Cache-Control' 'no-cache';

            # CORS setup
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length';

            # allow CORS preflight requests
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain charset=UTF-8';
                add_header 'Content-Length' 0;
                return 204;
            }

            types {
                application/dash+xml mpd;
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }

            root /tmp/;
        }
        
        # vod caches
        vod_metadata_cache metadata_cache 256m;
        vod_response_cache response_cache 128m;

        # vod settings
        vod_mode local;
        vod_segment_duration 2000; # 2s
        vod_align_segments_to_key_frames on;

        #file handle caching / aio
        open_file_cache max=1000 inactive=5m;
        open_file_cache_valid 2m;
        open_file_cache_min_uses 1;
        open_file_cache_errors on;
        aio on;

        location /video/ {
            alias /path/to/Videos/;
            vod hls;
            add_header Access-Control-Allow-Headers '*';
            add_header Access-Control-Expose-Headers 'Server,range,Content-Length,Content-Range';
            add_header Access-Control-Allow-Methods 'GET, HEAD, OPTIONS';
            add_header Access-Control-Allow-Origin '*';
            expires 100d;
        }
    }
}
EOL

chmod -R 755 /tmp/hls
ufw allow 1935/tcp
systemctl restart nginx



## for live RTMP with HLS check out
# - https://gist.github.com/afriza/ca7f41ccd0a358b45cf732532f977435/b9f3d918daa9e94313710b8a6b8abbc5e8b59687
## references:
# - https://www.nginx.com/blog/creating-installable-packages-dynamic-modules/
# - http://nginx.org/en/linux_packages.html#Ubuntu
# - https://docs.peer5.com/guides/setting-up-hls-live-streaming-server-using-nginx/
# - https://harry.web.id/2018/11/18/ubuntu-18-04-compile-nginx-rtmp-vod-hls/