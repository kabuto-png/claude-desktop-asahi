import React, { useState, useEffect } from 'react'
import './App.css'

function App() {
  const [serverStatus, setServerStatus] = useState<string>('Checking...')
  const [timestamp, setTimestamp] = useState<string>('')

  useEffect(() => {
    // Check server status
    const checkServerStatus = async () => {
      try {
        const apiUrl = import.meta.env.REACT_APP_API_URL || 'http://localhost:3010'
        const response = await fetch(`${apiUrl}/api/status`)
        const data = await response.json()
        
        setServerStatus('Connected ✅')
        setTimestamp(data.timestamp)
      } catch (error) {
        setServerStatus('Disconnected ❌')
        console.error('Failed to connect to server:', error)
      }
    }

    checkServerStatus()
    const interval = setInterval(checkServerStatus, 10000) // Check every 10 seconds

    return () => clearInterval(interval)
  }, [])

  return (
    <div className="App">
      <header className="App-header">
        <h1>🧠 Obsidian Remote MCP</h1>
        <p>AI-Powered Knowledge Management System</p>
        
        <div className="status-card">
          <h3>Server Status</h3>
          <p>{serverStatus}</p>
          {timestamp && <p className="timestamp">Last check: {new Date(timestamp).toLocaleString()}</p>}
        </div>

        <div className="features-grid">
          <div className="feature-card">
            <h4>📝 Knowledge Management</h4>
            <p>Intelligent note organization and retrieval</p>
          </div>
          
          <div className="feature-card">
            <h4>🔍 Semantic Search</h4>
            <p>Find information using natural language</p>
          </div>
          
          <div className="feature-card">
            <h4>📊 Analytics</h4>
            <p>Track your productivity and learning patterns</p>
          </div>
          
          <div className="feature-card">
            <h4>🔗 Integrations</h4>
            <p>Connect with external tools and services</p>
          </div>
        </div>

        <div className="coming-soon">
          <h3>🚧 Coming Soon</h3>
          <ul>
            <li>Real-time collaboration</li>
            <li>Advanced AI assistants</li>
            <li>Knowledge graph visualization</li>
            <li>Automated workflows</li>
          </ul>
        </div>
      </header>
    </div>
  )
}

export default App