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

# RTMP configuration
rtmp {
    server {
        listen 1935; # Listen on standard RTMP port
        chunk_size 4000;

        application show {
            live on;
            exec ffmpeg -re -i example-vid.mp4 -vcodec libx264 -vprofile baseline -g 30 -acodec aac -strict -2 -f flv rtmp://localhost/show/stream
            # Turn on HLS
            hls on;
            hls_path /mnt/hls/;
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
        listen 8080;

        location / {
            # Disable cache
            add_header 'Cache-Control' 'no-cache';

            # CORS setup
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length';

            # allow CORS preflight requests
            # if ($request_method = 'OPTIONS') {
            #     add_header 'Access-Control-Allow-Origin' '*';
            #     add_header 'Access-Control-Max-Age' 1728000;
            #     add_header 'Content-Type' 'text/plain charset=UTF-8';
            #     add_header 'Content-Length' 0;
            #     return 204;
            # }

            types {
                application/dash+xml mpd;
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }

            root /mnt/;
        }
    }
}
EOL

chmod -R 755 /tmp/hls
chmod -R 755 /mnt/hls
systemctl start nginx

systemctl reload nginx

# user  nginx;
# worker_processes  1;

# error_log  /var/log/nginx/error.log warn;
# pid        /var/run/nginx.pid;

# load_module modules/ngx_rtmp_module.so;
# load_module modules/ngx_http_vod_module.so;

# events {
#     worker_connections  1024;
# }

# rtmp_auto_push on;
# rtmp {
#     server {
#         listen 1935;
#         chunk_size 4000;

#         play_time_fix off;
#         interleave on;
#         publish_time_fix on;

#         application live {
#             live on;
#             record on;

#             exec ffmpeg -i rtmp://localhost/live/$name -threads 1 -c:v libx264 -profile:v baseline -b:v 350K -s 640x360 -f flv -c:a aac -ac 1 -strict -2 -b:a 56k rtmp://localhost/live360p/$name;
#             # Turn on HLS
#             hls on;
#             hls_path /tmp/hls;
#             hls_fragment 3;
#             hls_playlist_length 60;
#         }
#     }
# }

# http {
#     sendfile off;
#     tcp_nopush on;
#     aio on;
#     directio 512;
#     default_type application/octet-stream;

#     server {
#         listen 80;

#         location /hls {
#             # Disable cache
#             add_header 'Cache-Control' 'no-cache';

#             # CORS setup
#             add_header 'Access-Control-Allow-Origin' '*' always;
#             add_header 'Access-Control-Expose-Headers' 'Content-Length';

#             # allow CORS preflight requests
#             # if ($request_method = 'OPTIONS') {
#             #     add_header 'Access-Control-Allow-Origin' '*';
#             #     add_header 'Access-Control-Max-Age' 1728000;
#             #     add_header 'Content-Type' 'text/plain charset=UTF-8';
#             #     add_header 'Content-Length' 0;
#             #     return 204;
#             # }

#             types {
#                 application/dash+xml mpd;
#                 application/vnd.apple.mpegurl m3u8;
#                 video/mp2t ts;
#             }

#             root /tmp/;
#         }
        
#         # vod caches
#         vod_metadata_cache metadata_cache 256m;
#         vod_response_cache response_cache 128m;

#         # vod settings
#         vod_mode local;
#         vod_segment_duration 2000; # 2s
#         vod_align_segments_to_key_frames on;

#         #file handle caching / aio
#         open_file_cache max=1000 inactive=5m;
#         open_file_cache_valid 2m;
#         open_file_cache_min_uses 1;
#         open_file_cache_errors on;
#         aio on;

#         location /video/ {
#             alias /tmp/hls;
#             vod hls;
#             add_header Access-Control-Allow-Headers '*';
#             add_header Access-Control-Expose-Headers 'Server,range,Content-Length,Content-Range';
#             add_header Access-Control-Allow-Methods 'GET, HEAD, OPTIONS';
#             add_header Access-Control-Allow-Origin '*';
#             expires 100d;
#         }
#     }
# }