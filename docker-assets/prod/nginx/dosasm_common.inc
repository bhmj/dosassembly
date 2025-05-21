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

# index
location / {
    index index.html;
    ssi on;
    root /var/www/static/${DOSASM_DOMAIN}/;
    # TODO: switch to templating!
    # proxy_pass http://dosasm_service;
    # proxy_read_timeout 300;
    # proxy_connect_timeout 300;
    # proxy_send_timeout 300;
}

# api
location /api/ {
    proxy_pass  http://dosasm_service;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300; 
}

location ~ ^/(img)/ {
    root /var/www/static/${DOSASM_DOMAIN};
}

# Proxy all requests on port 3000 to Grafana
location /_grafana/ {
    proxy_pass http://grafana:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
