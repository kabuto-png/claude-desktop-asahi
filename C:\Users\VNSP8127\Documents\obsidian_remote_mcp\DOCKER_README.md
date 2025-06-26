# 🐳 Docker Environment - Quick Start Guide

## 🚀 Full Docker Setup for Obsidian Remote MCP

### Port Mapping (Conflict-Free):
- **🌐 Main App (Nginx)**: http://localhost:8080
- **📦 MCP Server**: http://localhost:3010  
- **🎨 Dashboard**: http://localhost:3011
- **🔍 Vector DB (ChromaDB)**: http://localhost:8010
- **🗃️ PostgreSQL**: localhost:5442
- **⚡ Redis**: localhost:6389

---

## ⚡ Quick Start (1-Minute Setup):

```bash
# 1. Make setup script executable
chmod +x setup-docker.sh

# 2. Run setup (checks ports, creates .env)
./setup-docker.sh

# 3. Start all services
docker-compose up -d

# 4. Check status
docker-compose ps

# 5. Access app
firefox http://localhost:8080
```

---

## 🐳 Docker Services:

### Core Services:
- **mcp-server**: MCP backend với Express + TypeScript
- **dashboard**: React frontend với Vite
- **postgres**: PostgreSQL database cho metadata
- **vectordb**: ChromaDB cho semantic search
- **redis**: Caching và session storage
- **nginx**: Reverse proxy và load balancer

### Features:
- ✅ Hot reload for development
- ✅ Volume mounts cho code changes
- ✅ Persistent data với named volumes
- ✅ Health checks for all services
- ✅ Network isolation
- ✅ Production-ready configuration

---

## 🔧 Development Commands:

```bash
# Start all services in background
docker-compose up -d

# Start with logs (foreground)
docker-compose up

# Stop all services
docker-compose down

# Rebuild and start
docker-compose up --build

# View logs
docker-compose logs -f [service-name]

# Execute commands trong container
docker-compose exec mcp-server npm run dev
docker-compose exec dashboard npm test

# Database access
docker-compose exec postgres psql -U postgres obsidian_mcp
```

---

## 📊 Service Health:

```bash
# Check all services
docker-compose ps

# Health check endpoints
curl http://localhost:3010/health  # MCP Server
curl http://localhost:8080/health  # Via Nginx
curl http://localhost:8010/health  # ChromaDB

# Service logs
docker-compose logs mcp-server
docker-compose logs dashboard
docker-compose logs postgres
```

---

## 📁 Volume Mounts:

### Development (Live Editing):
- `./server/src:/app/src` - Server code hot reload
- `./client/src:/app/src` - Client code hot reload
- `./obsidian:/app/vault` - Obsidian vault access

### Data Persistence:
- `postgres_data` - Database data
- `chroma_data` - Vector embeddings
- `redis_data` - Cache data

---

## 🔒 Environment Configuration:

```bash
# Copy and edit environment variables
cp .env.example .env
nano .env  # Edit with your settings

# Required API Keys:
OPENAI_API_KEY=sk-your-key-here
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

---

## 🛠️ Development Workflow:

### Initial Setup:
```bash
# 1. Clone/setup project
cd ~/Documents/obsidian_remote_mcp/

# 2. Make scripts executable
chmod +x setup-docker.sh

# 3. Run setup
./setup-docker.sh

# 4. Edit environment
cp .env.example .env
# Add your API keys to .env file
```

### Daily Development:
```bash
# Start development environment
docker-compose up -d

# Watch logs during development  
docker-compose logs -f mcp-server dashboard

# Make code changes (auto-reload enabled)
# Files in ./server/src and ./client/src auto-reload

# Run tests
docker-compose exec mcp-server npm test
docker-compose exec dashboard npm test

# Stop when done
docker-compose down
```

---

## 🔧 Advanced Operations:

### Database Operations:
```bash
# Access PostgreSQL
docker-compose exec postgres psql -U postgres obsidian_mcp

# Run migrations
docker-compose exec mcp-server npm run migrate

# Backup database
docker-compose exec postgres pg_dump -U postgres obsidian_mcp > backup.sql

# Restore database
docker-compose exec -T postgres psql -U postgres obsidian_mcp < backup.sql
```

### ChromaDB Operations:
```bash
# Access ChromaDB API
curl http://localhost:8010/api/v1/collections

# Check embeddings
curl http://localhost:8010/api/v1/collections/notes/count

# Reset vector database
docker-compose stop vectordb
docker volume rm obsidian_remote_mcp_chroma_data
docker-compose up -d vectordb
```

### Redis Operations:
```bash
# Access Redis CLI
docker-compose exec redis redis-cli

# Monitor Redis activity
docker-compose exec redis redis-cli monitor

# Clear cache
docker-compose exec redis redis-cli flushall
```

---

## 📦 Production Deployment:

### Build Production Images:
```bash
# Build optimized production images
docker-compose -f docker-compose.prod.yml build

# Start production environment
docker-compose -f docker-compose.prod.yml up -d
```

### Environment Variables for Production:
```bash
NODE_ENV=production
ENABLE_DEBUG=false
LOG_LEVEL=warn
POSTGRES_PASSWORD=your_secure_password
JWT_SECRET=your_super_secure_jwt_secret
```

---

## 🐛 Troubleshooting:

### Common Issues:

**Port Conflicts:**
```bash
# Check what's using your ports
netstat -tlnp | grep -E ":(3010|3011|8010|5442|6389|8080)"

# Kill conflicting processes
sudo kill -9 $(lsof -t -i:3000)  # Example
```

**Container Won't Start:**
```bash
# Check logs
docker-compose logs [service-name]

# Rebuild container
docker-compose build --no-cache [service-name]

# Remove and recreate
docker-compose down
docker-compose up --force-recreate
```

**Database Connection Issues:**
```bash
# Check PostgreSQL is running
docker-compose exec postgres pg_isready

# Test connection
docker-compose exec mcp-server npm run db:test
```

**File Permission Issues:**
```bash
# Fix ownership (if needed)
sudo chown -R $USER:$USER ./obsidian
sudo chown -R $USER:$USER ./server/src
sudo chown -R $USER:$USER ./client/src
```

---

## 📊 Monitoring & Logs:

### Real-time Monitoring:
```bash
# System resources
docker stats

# All service logs
docker-compose logs -f

# Specific service logs
docker-compose logs -f mcp-server
docker-compose logs -f dashboard

# Follow new logs only
docker-compose logs -f --tail=50
```

### Application Metrics:
- **Health Endpoints**: http://localhost:8080/health
- **API Metrics**: http://localhost:3010/metrics  
- **Database Stats**: Access via PostgreSQL queries

---

## 🚀 Next Steps:

After Docker environment is running:

1. **Configure Obsidian Vault**: Add notes to `./obsidian/` folder
2. **Test MCP Connection**: Connect Claude Desktop to MCP server
3. **Develop Features**: Edit code in `./server/src/` and `./client/src/`
4. **Add Integrations**: Configure external APIs in `.env`

**Main Access Point**: http://localhost:8080

**Ready to start development!** 🎉