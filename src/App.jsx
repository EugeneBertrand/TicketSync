import React from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import LoginPortal from './components/LoginPortal'
import ClientDashboard from './components/ClientDashboard'
import AdminDashboard from './components/AdminDashboard'
import ProtectedRoute from './components/ProtectedRoute'
import './App.css'

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<LoginPortal />} />
          <Route path="/login" element={<LoginPortal />} />
          <Route
            path="/client/*"
            element={
              <ProtectedRoute userType="client">
                <ClientDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin/*"
            element={
              <ProtectedRoute userType="admin">
                <AdminDashboard />
              </ProtectedRoute>
            }
          />
          {/* Temporary route for development to view customer portal without auth */}
          <Route path="/preview/client" element={<ClientDashboard />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </Router>
  )
}

export default App

