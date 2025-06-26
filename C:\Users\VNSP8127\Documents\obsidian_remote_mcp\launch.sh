#!/bin/bash
# FINAL SETUP - Launch Obsidian Remote MCP

set -e

echo "🐳 Launching Obsidian Remote MCP - Docker Environment"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Make setup executable and run
echo -e "${BLUE}Step 1: Running setup checks...${NC}"
chmod +x setup-docker.sh
./setup-docker.sh

# Step 2: Create .env file if not exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Step 2: Creating .env file...${NC}"
    cp .env.example .env
    echo "Please edit .env file with your API keys before continuing"
    echo "Press ENTER to continue or Ctrl+C to exit and edit .env"
    read
fi

# Step 3: Start all services
echo -e "${BLUE}Step 3: Starting all Docker services...${NC}"
echo "This may take a few minutes for first-time setup..."

docker-compose up -d --build

# Step 4: Wait for services to be ready
echo -e "${BLUE}Step 4: Waiting for services to start...${NC}"
sleep 10

# Step 5: Health checks
echo -e "${BLUE}Step 5: Checking service health...${NC}"

echo "Checking MCP Server..."
for i in {1..30}; do
    if curl -f http://localhost:3010/health &>/dev/null; then
        echo -e "${GREEN}✅ MCP Server: Ready${NC}"
        break
    fi
    echo "Waiting for MCP Server... ($i/30)"
    sleep 2
done

echo "Checking Dashboard..."
for i in {1..30}; do
    if curl -f http://localhost:3011 &>/dev/null; then
        echo -e "${GREEN}✅ Dashboard: Ready${NC}"
        break
    fi
    echo "Waiting for Dashboard... ($i/30)"
    sleep 2
done

echo "Checking Main App..."
for i in {1..30}; do
    if curl -f http://localhost:8080 &>/dev/null; then
        echo -e "${GREEN}✅ Main App: Ready${NC}"
        break
    fi
    echo "Waiting for Main App... ($i/30)"
    sleep 2
done

# Step 6: Display status
echo ""
echo "🎉 OBSIDIAN REMOTE MCP IS NOW RUNNING!"
echo "======================================"
echo ""
echo "📱 ACCESS POINTS:"
echo "🌐 Main Application: http://localhost:8080"
echo "📦 MCP Server API:   http://localhost:3010"
echo "🎨 Dashboard:        http://localhost:3011"
echo "🔍 Vector Database:  http://localhost:8010"
echo ""
echo "📊 SYSTEM STATUS:"
docker-compose ps
echo ""
echo "📋 USEFUL COMMANDS:"
echo "• View logs:         docker-compose logs -f"
echo "• Stop services:     docker-compose down"
echo "• Restart:           docker-compose restart"
echo "• Rebuild:           docker-compose up --build"
echo ""
echo "📚 VAULT INTEGRATION:"
echo "🧠 Obsidian Vault: Longneobsidian"
echo "📍 Location: /home/longne/Documents/GitHub/Longneobsidian"
echo "📊 Categories: 10+ organized folders"
echo ""
echo "🎯 MCP will now connect to your real vault!"
echo "✨ AI Assistant ready to explore your knowledge base"
echo ""
echo "🚀 Happy coding! Your Obsidian Remote MCP environment is ready!"

# Auto-open browser (optional)
if command -v xdg-open &> /dev/null; then
    echo "Opening browser..."
    xdg-open http://localhost:8080
elif command -v open &> /dev/null; then
    echo "Opening browser..."
    open http://localhost:8080
fi