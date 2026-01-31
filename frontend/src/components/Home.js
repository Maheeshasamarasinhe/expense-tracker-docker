import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './Home.css';
import axios from 'axios';
import API_URL from '../config';

const Home = ({ setAuth }) => {
  const [expenses, setExpenses] = useState([]);
  const [formData, setFormData] = useState({ title: '', amount: '', category: '' });
  const navigate = useNavigate();
  const user = JSON.parse(localStorage.getItem('user') || '{}');

  useEffect(() => {
    fetchExpenses();
  }, []);

  const fetchExpenses = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(`${API_URL}/api/expenses`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setExpenses(response.data);
    } catch (error) {
      console.error('Error fetching expenses:', error);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      await axios.post(`${API_URL}/api/expenses`, formData, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setFormData({ title: '', amount: '', category: '' });
      fetchExpenses();
    } catch (error) {
      alert('Error adding expense');
    }
  };

  const deleteExpense = async (id) => {
    try {
      const token = localStorage.getItem('token');
      await axios.delete(`${API_URL}/api/expenses/${id}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      fetchExpenses();
    } catch (error) {
      alert('Error deleting expense');
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setAuth(false);
    navigate('/login');
  };

  const total = expenses.reduce((sum, expense) => sum + expense.amount, 0);

  return (
    <div className="home-container">
      <div className="header">
        <h1>Welcome, {user.name}!</h1>
        <button onClick={logout} className="btn" style={{width: 'auto'}}>Logout</button>
      </div>

      <div className="expense-form">
        <h2>Add New Expense</h2>
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label>Title</label>
              <input
                type="text"
                value={formData.title}
                onChange={(e) => setFormData({...formData, title: e.target.value})}
                required
              />
            </div>
            <div className="form-group">
              <label>Amount</label>
              <input
                type="number"
                step="0.01"
                value={formData.amount}
                onChange={(e) => setFormData({...formData, amount: e.target.value})}
                required
              />
            </div>
            <div className="form-group">
              <label>Category</label>
              <input
                type="text"
                value={formData.category}
                onChange={(e) => setFormData({...formData, category: e.target.value})}
                required
              />
            </div>
            <button type="submit" className="btn">Add</button>
          </div>
        </form>
      </div>

      <div className="expense-list">
        <h2 style={{padding: '1rem 2rem', margin: 0, borderBottom: '1px solid #eee'}}>Your Expenses</h2>
        {expenses.length === 0 ? (
          <div style={{padding: '2rem', textAlign: 'center', color: '#666'}}>
            No expenses yet. Add your first expense above!
          </div>
        ) : (
          expenses.map(expense => (
            <div key={expense._id} className="expense-item">
              <div className="expense-info">
                <h3>{expense.title}</h3>
                <p>{expense.category} • {new Date(expense.date).toLocaleDateString()}</p>
              </div>
              <div style={{display: 'flex', alignItems: 'center'}}>
                <span className="expense-amount">${expense.amount}</span>
                <button 
                  onClick={() => deleteExpense(expense._id)} 
                  className="delete-btn"
                >
                  Delete
                </button>
              </div>
            </div>
          ))
        )}
        {expenses.length > 0 && (
          <div className="total">
            Total: ${total.toFixed(2)}
          </div>
        )}
      </div>
    </div>
  );
};

export default Home;