import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

// Amplify will be configured dynamically in the LoginPortal component
// based on the user's selection (client or admin)
// This allows us to use separate Cognito User Pools for each user type

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)

