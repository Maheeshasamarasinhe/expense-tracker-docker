# Expense Tracker Application

A full-stack expense tracking application with React frontend, Node.js/Express backend, and MongoDB database.

## Features

- User authentication (signup/login)
- Add, view, and delete expenses
- Expense categorization
- Total expense calculation
- Responsive design

## Quick Start

### Using Docker (Recommended)

1. Make sure Docker is installed and running
2. Run the application:
   ```bash
   docker-compose up --build
   ```
3. Access the application:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:4000
   - MongoDB: localhost:27017

### Manual Setup

#### Backend Setup
```bash
cd backend
npm install
npm start
```

#### Frontend Setup
```bash
cd frontend
npm install
npm start
```

#### MongoDB Setup
- Install MongoDB locally or use MongoDB Atlas
- Update MONGODB_URI in backend/.env

## API Endpoints

- POST /api/signup - User registration
- POST /api/login - User login
- GET /api/expenses - Get user expenses
- POST /api/expenses - Add new expense
- DELETE /api/expenses/:id - Delete expense

## Usage

1. Sign up for a new account
2. Login with your credentials
3. Add expenses with title, amount, and category
4. View your expense list and total
5. Delete expenses as needed

## Technologies Used

- Frontend: React, React Router, Axios
- Backend: Node.js, Express, JWT, bcryptjs
- Database: MongoDB, Mongoose
- Containerization: Docker, Docker Compose