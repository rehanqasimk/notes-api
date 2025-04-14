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

# Pre-SSL Check
echo "Ensuring proper security group settings for SSL..."
echo "Please verify that your EC2 security group allows the following inbound traffic:"
echo "- HTTP (port 80) from 0.0.0.0/0"
echo "- HTTPS (port 443) from 0.0.0.0/0"
echo "This is required for Let's Encrypt to verify domain ownership."
echo ""
echo "If you need to update your security group settings:"
echo "1. Go to the EC2 console"
echo "2. Select your instance"
echo "3. Click on the Security tab"
echo "4. Click on the security group link"
echo "5. Edit inbound rules to add HTTP and HTTPS from anywhere"
echo ""
read -p "Have you confirmed these security group settings? (y/n): " confirm
if [ "$confirm" != "y" ]; then
  echo "Please update your security group settings and run this script again."
  exit 1
fi

echo "Checking domain DNS configuration..."
echo "Attempting to resolve api.notes.rehanqasim.com..."
host_ip=$(dig +short api.notes.rehanqasim.com)
my_ip=$(curl -s http://checkip.amazonaws.com/)

if [ -z "$host_ip" ]; then
  echo "ERROR: Domain api.notes.rehanqasim.com does not resolve to any IP address."
  echo "Please ensure your DNS settings point to your EC2 instance public IP."
  exit 1
elif [ "$host_ip" != "$my_ip" ]; then
  echo "WARNING: Domain api.notes.rehanqasim.com resolves to $host_ip, but this server's public IP is $my_ip"
  echo "You may need to update your DNS settings and wait for propagation."
  echo ""
  echo "You have two options:"
  echo "1. Update your DNS settings to point to $my_ip and wait for propagation (recommended)"
  echo "2. Use DNS-01 challenge instead of HTTP-01 for verification"
  echo ""
  read -p "What would you like to do? (1: Update DNS, 2: Use DNS challenge, 3: Try HTTP challenge anyway): " dns_option
  
  case $dns_option in
    1)
      echo "Please update your DNS settings now and run this script again when DNS has propagated."
      exit 0
      ;;
    2)
      echo "Using DNS-01 challenge for domain verification..."
      # Install certbot and DNS plugins
      sudo dnf install certbot python3-certbot-dns-route53 -y
      
      echo "To use DNS challenge, you'll need to set up credentials for your DNS provider."
      echo "For AWS Route53, ensure your EC2 instance has an IAM role with Route53 permissions."
      echo "For other providers, you may need to install specific plugins."
      echo ""
      
      read -p "Which DNS provider are you using? (route53, cloudflare, etc.): " dns_provider
      
      if [ "$dns_provider" = "route53" ]; then
        echo "Using Route53 for DNS challenge..."
        sudo certbot --dns-route53 -d api.notes.rehanqasim.com --non-interactive --agree-tos --email qkrehan@gmail.com
      else
        echo "For other DNS providers, you'll need to install specific plugins and configure credentials."
        echo "Please refer to Certbot documentation for your specific provider."
        echo "For now, we'll proceed with manual DNS challenge."
        
        sudo certbot certonly --manual --preferred-challenges dns -d api.notes.rehanqasim.com --agree-tos --email qkrehan@gmail.com
        
        # After obtaining the certificate, configure Nginx to use it
        echo "Configuring Nginx to use the newly obtained certificate..."
        sudo tee /etc/nginx/conf.d/notes-api-ssl.conf > /dev/null <<EOL
server {
    listen 443 ssl;
    server_name api.notes.rehanqasim.com;
    
    ssl_certificate /etc/letsencrypt/live/api.notes.rehanqasim.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.notes.rehanqasim.com/privkey.pem;
    
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

server {
    listen 80;
    server_name api.notes.rehanqasim.com;
    return 301 https://\$host\$request_uri;
}
EOL
        sudo nginx -t && sudo systemctl reload nginx
      fi
      
      exit 0
      ;;
    3)
      echo "Attempting HTTP challenge anyway (Note: This will likely fail)..."
      # Continue with original approach
      ;;
    *)
      echo "Invalid option. Please run the script again."
      exit 1
      ;;
  esac
else
  echo "Domain properly resolves to this server. Continuing..."
fi

# Amazon Linux 2023 uses dnf instead of amazon-linux-extras
sudo dnf install certbot python3-certbot-nginx -y

# Obtain SSL certificate
sudo certbot --nginx -d api.notes.rehanqasim.com --non-interactive --agree-tos --email qkrehan@gmail.com

echo "Deployment completed successfully!"