import React from 'react';
import { Link } from 'react-router-dom';
import './Landing.css';

const Landing = () => {
  return (
    <div className="landing-container">
      <div className="landing-content">
        <h1>Expense Tracker</h1>
        <p>Track your expenses easily and efficiently</p>
        <Link to="/login" className="get-started-btn">
          Get Started
        </Link>
      </div>
    </div>
  );
};

export default Landing;