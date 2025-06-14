listen 443 ssl;

gzip   on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

# proxy: common headers
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

# robots etc
location /robots.txt {
    root /var/www/static/${DOSASM_DOMAIN}/;
}

# saved source
location ~ ^/([A-Za-z0-9])/?$ {
    proxy_pass http://dosasm_service;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
}

# index
location / {
    proxy_pass http://dosasm_service;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
}

# api
location /api/ {
    proxy_pass  http://dosasm_service;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300; 
}

location ~ ^/(img|js|styles|examples|guides)/ {
    root /var/www/static/${DOSASM_DOMAIN};
}
