#!/bin/bash

# Exit on any error
set -e

# Update system packages
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Node.js and npm
echo "Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
echo "Installing PM2 process manager..."
sudo npm install pm2 -g

# Install PostgreSQL client (for database migrations if needed)
echo "Installing PostgreSQL client..."
sudo apt-get install -y postgresql-client

# Create app directory
echo "Setting up application directory..."
sudo mkdir -p /var/www/notes-api
sudo chown -R $USER:$USER /var/www/notes-api

# Install Nginx web server
echo "Installing and configuring Nginx..."
sudo apt-get install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Configure Nginx as reverse proxy
echo "Creating Nginx configuration..."
sudo tee /etc/nginx/sites-available/notes-api <<EOF
server {
    listen 80;
    server_name api.notes.rehanqasim.com;

    location / {
        proxy_pass http://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/notes-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "EC2 instance setup complete! Now deploy your application to /var/www/notes-api"