import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Landing from './components/Landing';
import Login from './components/Login';
import Signup from './components/Signup';
import Home from './components/Home';
import './App.css';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(!!localStorage.getItem('token'));

  useEffect(() => {
    const token = localStorage.getItem('token');
    setIsAuthenticated(!!token);
  }, []);

  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={!isAuthenticated ? <Landing /> : <Navigate to="/home" />} />
          <Route path="/login" element={!isAuthenticated ? <Login setAuth={setIsAuthenticated} /> : <Navigate to="/home" />} />
          <Route path="/signup" element={!isAuthenticated ? <Signup /> : <Navigate to="/home" />} />
          <Route path="/home" element={isAuthenticated ? <Home setAuth={setIsAuthenticated} /> : <Navigate to="/" />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;