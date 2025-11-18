import React, { useState } from 'react'
import { signIn, signUp, confirmSignUp, resendSignUpCode } from 'aws-amplify/auth'
import { useNavigate } from 'react-router-dom'
import './LoginPortal.css'

const LoginPortal = () => {
  const [userType, setUserType] = useState(null) // 'client' or 'admin'
  const [isSignUp, setIsSignUp] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [confirmationCode, setConfirmationCode] = useState('')
  const [needsConfirmation, setNeedsConfirmation] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  // Cognito User Pool IDs - these should come from environment variables
  // Set based on the selected userType
  const getUserPoolConfig = () => {
    if (userType === 'client') {
      return {
        userPoolId: import.meta.env.VITE_CLIENT_USER_POOL_ID || '',
        userPoolClientId: import.meta.env.VITE_CLIENT_USER_POOL_CLIENT_ID || '',
      }
    } else if (userType === 'admin') {
      return {
        userPoolId: import.meta.env.VITE_ADMIN_USER_POOL_ID || '',
        userPoolClientId: import.meta.env.VITE_ADMIN_USER_POOL_CLIENT_ID || '',
      }
    }
    return null
  }

  const handleUserTypeSelection = (type) => {
    setUserType(type)
    setError('')
    setIsSignUp(false)
    setNeedsConfirmation(false)
    setEmail('')
    setPassword('')
    setConfirmPassword('')
    setConfirmationCode('')
  }

  const handleSignIn = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const config = getUserPoolConfig()
      if (!config) {
        throw new Error('Please select a user type')
      }

      if (!config.userPoolId || !config.userPoolClientId) {
        throw new Error('Cognito configuration is missing. Please check your environment variables.')
      }

      // Update Amplify config for the selected user pool
      const { Amplify } = await import('aws-amplify')
      Amplify.configure({
        Auth: {
          Cognito: {
            userPoolId: config.userPoolId,
            userPoolClientId: config.userPoolClientId,
            loginWith: {
              email: true,
            }
          }
        }
      }, { ssr: true })

      const { nextStep } = await signIn({
        username: email,
        password: password
      })

      // Check if sign in was successful
      if (nextStep.signInStep === 'DONE') {
        // Navigate to appropriate dashboard
        if (userType === 'client') {
          navigate('/client')
        } else if (userType === 'admin') {
          navigate('/admin')
        }
      } else {
        throw new Error('Sign in incomplete. Please try again.')
      }
    } catch (err) {
      setError(err.message || 'Failed to sign in')
      console.error('Sign in error:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleSignUp = async (e) => {
    e.preventDefault()
    setError('')

    if (password !== confirmPassword) {
      setError('Passwords do not match')
      return
    }

    const minLength = userType === 'admin' ? 10 : 8
    if (password.length < minLength) {
      setError(`Password must be at least ${minLength} characters long`)
      return
    }

    setLoading(true)

    try {
      const config = getUserPoolConfig()
      if (!config) {
        throw new Error('Please select a user type')
      }

      if (!config.userPoolId || !config.userPoolClientId) {
        throw new Error('Cognito configuration is missing. Please check your environment variables.')
      }

      // Update Amplify config for the selected user pool
      const { Amplify } = await import('aws-amplify')
      Amplify.configure({
        Auth: {
          Cognito: {
            userPoolId: config.userPoolId,
            userPoolClientId: config.userPoolClientId,
            loginWith: {
              email: true,
            }
          }
        }
      }, { ssr: true })

      await signUp({
        username: email,
        password: password,
        options: {
          userAttributes: {
            email: email,
          }
        }
      })

      setNeedsConfirmation(true)
    } catch (err) {
      setError(err.message || 'Failed to sign up')
      console.error('Sign up error:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleConfirmSignUp = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      await confirmSignUp({
        username: email,
        confirmationCode: confirmationCode
      })

      setNeedsConfirmation(false)
      setIsSignUp(false)
      setError('')
      alert('Account confirmed! Please sign in.')
    } catch (err) {
      setError(err.message || 'Failed to confirm sign up')
      console.error('Confirmation error:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleResendCode = async () => {
    setError('')
    setLoading(true)

    try {
      await resendSignUpCode({ username: email })
      alert('Confirmation code resent to your email')
    } catch (err) {
      setError(err.message || 'Failed to resend code')
    } finally {
      setLoading(false)
    }
  }

  // User type selection screen
  if (!userType) {
    return (
      <div className="login-portal">
        <div className="login-container">
          <div className="login-header">
            <h1>TicketSync</h1>
            <p className="subtitle">Welcome to TicketSync</p>
            <p className="description">Please select your login type</p>
          </div>
          <div className="user-type-selection">
            <button
              className="user-type-button client-button"
              onClick={() => handleUserTypeSelection('client')}
            >
              <div className="button-icon">👤</div>
              <div className="button-content">
                <h2>Client Login</h2>
                <p>Submit and track your support tickets</p>
              </div>
            </button>
            <button
              className="user-type-button admin-button"
              onClick={() => handleUserTypeSelection('admin')}
            >
              <div className="button-icon">🔧</div>
              <div className="button-content">
                <h2>Admin Login</h2>
                <p>Manage and respond to support tickets</p>
              </div>
            </button>
          </div>
        </div>
      </div>
    )
  }

  // Confirmation code screen
  if (needsConfirmation) {
    return (
      <div className="login-portal">
        <div className="login-container">
          <div className="login-header">
            <h1>Confirm Your Account</h1>
            <p className="subtitle">
              We've sent a confirmation code to {email}
            </p>
          </div>
          <form onSubmit={handleConfirmSignUp} className="login-form">
            {error && <div className="error-message">{error}</div>}
            <div className="form-group">
              <label htmlFor="confirmationCode">Confirmation Code</label>
              <input
                id="confirmationCode"
                type="text"
                value={confirmationCode}
                onChange={(e) => setConfirmationCode(e.target.value)}
                placeholder="Enter confirmation code"
                required
              />
            </div>
            <button type="submit" className="submit-button" disabled={loading}>
              {loading ? 'Confirming...' : 'Confirm Account'}
            </button>
            <button
              type="button"
              className="resend-button"
              onClick={handleResendCode}
              disabled={loading}
            >
              Resend Code
            </button>
            <button
              type="button"
              className="back-button"
              onClick={() => {
                setNeedsConfirmation(false)
                setIsSignUp(true)
              }}
            >
              Back to Sign Up
            </button>
          </form>
        </div>
      </div>
    )
  }

  // Sign in / Sign up screen
  return (
    <div className="login-portal">
      <div className="login-container">
        <div className="login-header">
          <button
            className="back-to-selection"
            onClick={() => handleUserTypeSelection(null)}
          >
            ← Back
          </button>
          <h1>
            {userType === 'client' ? 'Client' : 'Admin'} Login
          </h1>
          <p className="subtitle">
            {isSignUp ? 'Create a new account' : 'Sign in to your account'}
          </p>
        </div>
        <form
          onSubmit={isSignUp ? handleSignUp : handleSignIn}
          className="login-form"
        >
          {error && <div className="error-message">{error}</div>}
          <div className="form-group">
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter your email"
              required
            />
          </div>
          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter your password"
              required
            />
          </div>
          {isSignUp && (
            <div className="form-group">
              <label htmlFor="confirmPassword">Confirm Password</label>
              <input
                id="confirmPassword"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Confirm your password"
                required
              />
            </div>
          )}
          <button type="submit" className="submit-button" disabled={loading}>
            {loading
              ? isSignUp
                ? 'Signing up...'
                : 'Signing in...'
              : isSignUp
              ? 'Sign Up'
              : 'Sign In'}
          </button>
          <div className="form-footer">
            <button
              type="button"
              className="toggle-mode-button"
              onClick={() => {
                setIsSignUp(!isSignUp)
                setError('')
              }}
            >
              {isSignUp
                ? 'Already have an account? Sign in'
                : "Don't have an account? Sign up"}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default LoginPortal

