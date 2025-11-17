import React, { useState } from 'react'
import { signOut } from 'aws-amplify/auth'
import { useNavigate } from 'react-router-dom'
import './Dashboard.css'

const AdminDashboard = () => {
  const navigate = useNavigate()
  
  // Sample tickets with different priorities and statuses
  const [tickets, setTickets] = useState([
    { 
      id: 1, 
      title: 'High Priority Issue', 
      description: 'Critical system error affecting multiple users', 
      status: 'Pending',
      priority: 'high',
      createdAt: '2025-11-15T10:30:00Z',
      createdBy: 'user1@example.com'
    },
    { 
      id: 2, 
      title: 'Feature Request', 
      description: 'Add export to PDF functionality', 
      status: 'Pending',
      priority: 'medium',
      createdAt: '2025-11-16T09:15:00Z',
      createdBy: 'user2@example.com'
    },
    { 
      id: 3, 
      title: 'UI Bug', 
      description: 'Button alignment issue on mobile', 
      status: 'In Progress',
      priority: 'low',
      createdAt: '2025-11-16T14:45:00Z',
      createdBy: 'user3@example.com'
    },
    { 
      id: 4, 
      title: 'Login Issue', 
      description: 'Password reset not working', 
      status: 'Completed',
      priority: 'high',
      createdAt: '2025-11-14T16:20:00Z',
      completedAt: '2025-11-15T10:00:00Z',
      createdBy: 'user4@example.com'
    }
  ])

  const [selectedTicket, setSelectedTicket] = useState(null)
  const [activeFilter, setActiveFilter] = useState('all') // 'all', 'pending', 'in-progress', 'completed'

  const handleSignOut = async () => {
    try {
      await signOut({ global: true })
      navigate('/login')
    } catch (error) {
      console.error('Error signing out:', error)
      navigate('/login')
    }
  }

  const handleStatusChange = (ticketId, newStatus) => {
    setTickets(tickets.map(ticket => 
      ticket.id === ticketId 
        ? { 
            ...ticket, 
            status: newStatus,
            ...(newStatus === 'Completed' && !ticket.completedAt 
              ? { completedAt: new Date().toISOString() } 
              : {})
          } 
        : ticket
    ))
    setSelectedTicket(null)
  }

  const getPriorityLabel = (priority) => {
    switch(priority) {
      case 'high': return 'High Priority';
      case 'medium': return 'Medium Priority';
      case 'low': return 'Low Priority';
      default: return priority;
    }
  }

  const getPriorityOrder = (priority) => {
    switch(priority) {
      case 'high': return 1;
      case 'medium': return 2;
      case 'low': return 3;
      default: return 4;
    }
  }

  const filteredTickets = tickets
    .filter(ticket => {
      if (activeFilter === 'all') return true;
      return ticket.status.toLowerCase() === activeFilter.toLowerCase().replace('-', ' ');
    })
    .sort((a, b) => {
      // First sort by priority
      const priorityDiff = getPriorityOrder(a.priority) - getPriorityOrder(b.priority);
      if (priorityDiff !== 0) return priorityDiff;
      
      // Then by creation date (newest first)
      return new Date(b.createdAt) - new Date(a.createdAt);
    });

  return (
    <div className="dashboard admin-dashboard">
      <header className="dashboard-header">
        <h1>Admin Dashboard</h1>
        <button onClick={handleSignOut} className="sign-out-button">
          Sign Out
        </button>
      </header>
      
      <main className="dashboard-content">
        <div className="welcome-section">
          <h2>Welcome, Administrator</h2>
          <p>Manage and respond to support tickets below.</p>
          
          <div className="ticket-filters">
            <button 
              className={`filter-btn ${activeFilter === 'all' ? 'active' : ''}`}
              onClick={() => setActiveFilter('all')}
            >
              All Tickets
            </button>
            <button 
              className={`filter-btn ${activeFilter === 'pending' ? 'active' : ''}`}
              onClick={() => setActiveFilter('pending')}
            >
              Pending
            </button>
            <button 
              className={`filter-btn ${activeFilter === 'in-progress' ? 'active' : ''}`}
              onClick={() => setActiveFilter('in-progress')}
            >
              In Progress
            </button>
            <button 
              className={`filter-btn ${activeFilter === 'completed' ? 'active' : ''}`}
              onClick={() => setActiveFilter('completed')}
            >
              Completed
            </button>
          </div>
        </div>

        <div className="ticket-section">
          {filteredTickets.length === 0 ? (
            <p className="no-tickets">No {activeFilter === 'all' ? '' : activeFilter} tickets found.</p>
          ) : (
            <div className="ticket-list">
              {filteredTickets.map(ticket => (
                <div 
                  key={ticket.id} 
                  className={`ticket-card ${ticket.priority}-priority ${ticket.status.toLowerCase().replace(' ', '-')}`}
                  onClick={() => setSelectedTicket(ticket)}
                >
                  <div className="ticket-main">
                    <div className="ticket-header">
                      <h3>{ticket.title}</h3>
                      <div className="ticket-meta">
                        <span className={`priority-badge ${ticket.priority}`}>
                          {getPriorityLabel(ticket.priority)}
                        </span>
                        <span className={`status-badge ${ticket.status.toLowerCase().replace(' ', '-')}`}>
                          {ticket.status}
                        </span>
                      </div>
                    </div>
                    <p className="ticket-desc">{ticket.description}</p>
                    <div className="ticket-footer">
                      <span className="ticket-meta-item">
                        <i className="fas fa-user"></i> {ticket.createdBy}
                      </span>
                      <span className="ticket-meta-item">
                        <i className="far fa-calendar-alt"></i> {new Date(ticket.createdAt).toLocaleDateString()}
                      </span>
                      {ticket.completedAt && (
                        <span className="ticket-meta-item completed">
                          <i className="fas fa-check"></i> Completed: {new Date(ticket.completedAt).toLocaleDateString()}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Ticket Detail Modal */}
        {selectedTicket && (
          <div className="modal-overlay" onClick={() => setSelectedTicket(null)}>
            <div className="modal-content" onClick={e => e.stopPropagation()}>
              <div className="modal-header">
                <h2>{selectedTicket.title}</h2>
                <button className="close-button" onClick={() => setSelectedTicket(null)}>×</button>
              </div>
              <div className="modal-body">
                <div className="ticket-details">
                  <div className="detail-row">
                    <span className="detail-label">Status:</span>
                    <span className={`status-badge ${selectedTicket.status.toLowerCase().replace(' ', '-')}`}>
                      {selectedTicket.status}
                    </span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Priority:</span>
                    <span className={`priority-badge ${selectedTicket.priority}`}>
                      {getPriorityLabel(selectedTicket.priority)}
                    </span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Created By:</span>
                    <span>{selectedTicket.createdBy}</span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Created At:</span>
                    <span>{new Date(selectedTicket.createdAt).toLocaleString()}</span>
                  </div>
                  {selectedTicket.completedAt && (
                    <div className="detail-row">
                      <span className="detail-label">Completed At:</span>
                      <span>{new Date(selectedTicket.completedAt).toLocaleString()}</span>
                    </div>
                  )}
                  <div className="detail-description">
                    <h4>Description</h4>
                    <p>{selectedTicket.description}</p>
                  </div>
                </div>
                
                {selectedTicket.status !== 'Completed' && (
                  <div className="action-buttons">
                    <h4>Update Status</h4>
                    <div className="button-group">
                      <button 
                        className={`status-button ${selectedTicket.status === 'In Progress' ? 'active' : ''}`}
                        onClick={() => handleStatusChange(selectedTicket.id, 'In Progress')}
                      >
                        Mark as In Progress
                      </button>
                      <button 
                        className="status-button complete"
                        onClick={() => handleStatusChange(selectedTicket.id, 'Completed')}
                      >
                        Mark as Completed
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  )
}

export default AdminDashboard

