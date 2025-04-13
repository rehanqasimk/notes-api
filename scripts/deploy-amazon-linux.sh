#!/bin/bash

# Exit on error
set -e

echo "Deploying Notes API to Amazon Linux EC2..."

# Install necessary dependencies
echo "Installing dependencies..."
sudo yum update -y
sudo yum install -y git

# Install Node.js using Amazon Linux extras
echo "Installing Node.js..."
sudo yum install -y gcc-c++ make
curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Install PostgreSQL client tools
echo "Installing PostgreSQL client tools..."
# Amazon Linux 2023 uses dnf instead of amazon-linux-extras
sudo dnf install postgresql15 -y

# Set up Nginx
echo "Installing and configuring Nginx..."
sudo dnf install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

# Create application directory
echo "Setting up application directory..."
sudo mkdir -p /var/www/notes-api
sudo chown ec2-user:ec2-user /var/www/notes-api

# Clone or update repository
if [ -d "/var/www/notes-api/.git" ]; then
  echo "Repository exists, updating..."
  cd /var/www/notes-api
  git pull
else
  echo "Cloning repository..."
  # Using HTTPS with personal access token (recommended for automation)
  # The script will expect the token to be set as an environment variable
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN environment variable not set. Please provide it:"
    read -s GITHUB_TOKEN
    echo
  fi
  
  git clone https://rehanqasimk:${GITHUB_TOKEN}@github.com/rehanqasimk/notes-api.git /var/www/notes-api
  cd /var/www/notes-api
fi

# Install dependencies and build
echo "Installing npm dependencies..."
npm ci

# Create .env file if it doesn't exist
if [ ! -f "/var/www/notes-api/.env" ]; then
  echo "Creating .env file..."
  cp .env.example .env
  
  # Prompt for environment variables
  echo "Please provide the following environment variables:"
  
  read -p "DATABASE_URL (e.g., postgresql://user:password@hostname:5432/dbname): " db_url
  read -p "JWT_SECRET (generate a secure string): " jwt_secret
  read -p "PORT (default: 5001): " port
  port=${port:-5001}
  read -p "FRONTEND_URL (e.g., https://notes.rehanqasim.com): " frontend_url
  
  # Update .env file
  sed -i "s|DATABASE_URL=.*|DATABASE_URL=\"$db_url\"|g" .env
  sed -i "s|JWT_SECRET=.*|JWT_SECRET=\"$jwt_secret\"|g" .env
  sed -i "s|PORT=.*|PORT=$port|g" .env
  sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=\"$frontend_url\"|g" .env
  sed -i "s|NODE_ENV=.*|NODE_ENV=\"production\"|g" .env
fi

# Build the application
echo "Building application..."
npm run build

# Run database migrations
echo "Running database migrations..."
npx prisma migrate deploy

# Configure PM2 to run the application
echo "Configuring PM2..."
pm2 start dist/server.js --name "notes-api" || pm2 restart notes-api
pm2 save
pm2 startup | sudo bash

# Configure Nginx
echo "Configuring Nginx as reverse proxy..."
sudo tee /etc/nginx/conf.d/notes-api.conf > /dev/null <<EOL
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
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Set up SSL with Certbot
echo "Setting up SSL with Certbot..."
# Amazon Linux 2023 uses dnf instead of amazon-linux-extras
sudo dnf install certbot python3-certbot-nginx -y

# Obtain SSL certificate
sudo certbot --nginx -d api.notes.rehanqasim.com --non-interactive --agree-tos --email your-email@example.com

echo "Deployment completed successfully!"