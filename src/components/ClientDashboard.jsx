import React, { useState } from 'react'
import { signOut } from 'aws-amplify/auth'
import { useNavigate } from 'react-router-dom'
import './Dashboard.css'

const ClientDashboard = () => {
  const navigate = useNavigate()
  const [tickets, setTickets] = useState([
    { id: 1, title: 'Login Issue', description: 'Unable to login to my account', status: 'Pending' },
    { id: 2, title: 'Feature Request', description: 'Add dark mode', status: 'Completed' }
  ])
  const [newTicket, setNewTicket] = useState({ title: '', description: '' })
  const [activeTab, setActiveTab] = useState('all') // 'all' or 'pending' or 'completed'

  const handleSignOut = async () => {
    try {
      await signOut({ global: true })
      navigate('/login')
    } catch (error) {
      console.error('Error signing out:', error)
      navigate('/login')
    }
  }

  const handleInputChange = (e) => {
    const { name, value } = e.target
    setNewTicket(prev => ({ ...prev, [name]: value }))
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    if (newTicket.title.trim() && newTicket.description.trim()) {
      const newTicketObj = {
        id: Date.now(),
        title: newTicket.title,
        description: newTicket.description,
        status: 'Pending',
        createdAt: new Date().toISOString()
      }
      setTickets([newTicketObj, ...tickets])
      setNewTicket({ title: '', description: '' })
    }
  }

  const filteredTickets = tickets.filter(ticket => {
    if (activeTab === 'all') return true
    return ticket.status.toLowerCase() === activeTab.toLowerCase()
  })

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <h1>Client Dashboard</h1>
        <button onClick={handleSignOut} className="sign-out-button">
          Sign Out
        </button>
      </header>
      <main className="dashboard-content">
        <div className="welcome-section">
          <h2>Submit a New Request</h2>
          <form onSubmit={handleSubmit} className="ticket-form">
            <div className="form-group">
              <label htmlFor="title">Title</label>
              <input
                type="text"
                id="title"
                name="title"
                value={newTicket.title}
                onChange={handleInputChange}
                placeholder="Enter a brief title"
                required
              />
            </div>
            <div className="form-group">
              <label htmlFor="description">Description</label>
              <textarea
                id="description"
                name="description"
                value={newTicket.description}
                onChange={handleInputChange}
                placeholder="Describe your issue or request in detail"
                rows="4"
                required
              />
            </div>
            <button type="submit" className="submit-button">Submit Request</button>
          </form>
        </div>
        
        <div className="ticket-section">
          <div className="ticket-header">
            <h2>Your Requests</h2>
            <div className="ticket-filters">
              <button 
                className={`filter-btn ${activeTab === 'all' ? 'active' : ''}`}
                onClick={() => setActiveTab('all')}
              >
                All
              </button>
              <button 
                className={`filter-btn ${activeTab === 'pending' ? 'active' : ''}`}
                onClick={() => setActiveTab('pending')}
              >
                Pending
              </button>
              <button 
                className={`filter-btn ${activeTab === 'completed' ? 'active' : ''}`}
                onClick={() => setActiveTab('completed')}
              >
                Completed
              </button>
            </div>
          </div>
          
          {filteredTickets.length === 0 ? (
            <p className="no-tickets">No {activeTab === 'all' ? '' : activeTab} tickets found.</p>
          ) : (
            <div className="ticket-list">
              {filteredTickets.map(ticket => (
                <div key={ticket.id} className={`ticket-card ${ticket.status.toLowerCase()}`}>
                  <div className="ticket-main">
                    <h3>{ticket.title}</h3>
                    <span className={`status-badge ${ticket.status.toLowerCase()}`}>
                      {ticket.status}
                    </span>
                  </div>
                  <p className="ticket-desc">{ticket.description}</p>
                  <div className="ticket-footer">
                    <span className="ticket-date">
                      {new Date(ticket.createdAt).toLocaleDateString()}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  )
}

export default ClientDashboard

