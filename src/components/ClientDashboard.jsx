import React from 'react'
import { signOut } from 'aws-amplify/auth'
import { useNavigate } from 'react-router-dom'
import './Dashboard.css'

const ClientDashboard = () => {
  const navigate = useNavigate()

  const handleSignOut = async () => {
    try {
      await signOut({ global: true })
      navigate('/login')
    } catch (error) {
      console.error('Error signing out:', error)
      // Navigate anyway in case of error
      navigate('/login')
    }
  }

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
          <h2>Welcome to TicketSync</h2>
          <p>Submit and track your support tickets here.</p>
        </div>
        <div className="dashboard-section">
          <h3>Your Tickets</h3>
          <p>Ticket management functionality will be implemented here.</p>
        </div>
      </main>
    </div>
  )
}

export default ClientDashboard

