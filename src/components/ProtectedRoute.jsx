import React, { useEffect, useState } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { fetchAuthSession } from 'aws-amplify/auth'
import { Amplify } from 'aws-amplify'

const ProtectedRoute = ({ children, userType }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(null)
  const [loading, setLoading] = useState(true)
  const location = useLocation()

  useEffect(() => {
    const checkAuth = async () => {
      try {
        // Configure Amplify based on the user type (determined from route)
        // This ensures Amplify is configured even if user refreshes the page
        const isAdminRoute = location.pathname.startsWith('/admin')
        const config = isAdminRoute
          ? {
              Auth: {
                Cognito: {
                  userPoolId: import.meta.env.VITE_ADMIN_USER_POOL_ID || '',
                  userPoolClientId: import.meta.env.VITE_ADMIN_USER_POOL_CLIENT_ID || '',
                  loginWith: {
                    email: true,
                  }
                }
              }
            }
          : {
              Auth: {
                Cognito: {
                  userPoolId: import.meta.env.VITE_CLIENT_USER_POOL_ID || '',
                  userPoolClientId: import.meta.env.VITE_CLIENT_USER_POOL_CLIENT_ID || '',
                  loginWith: {
                    email: true,
                  }
                }
              }
            }

        // Only configure if we have the required values
        if (config.Auth.Cognito.userPoolId && config.Auth.Cognito.userPoolClientId) {
          Amplify.configure(config, { ssr: true })
        }

        const session = await fetchAuthSession()
        // Check if we have valid tokens
        if (session.tokens && session.tokens.idToken) {
          setIsAuthenticated(true)
        } else {
          setIsAuthenticated(false)
        }
      } catch (error) {
        setIsAuthenticated(false)
      } finally {
        setLoading(false)
      }
    }

    checkAuth()
  }, [location.pathname])

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '18px'
      }}>
        Loading...
      </div>
    )
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }

  return children
}

export default ProtectedRoute

