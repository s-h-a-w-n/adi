import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Home from './components/Home';
import Patterns from './components/Patterns';
import FAQs from './components/FAQs';
import About from './components/About';
import NotFound from './components/NotFound';
import NavigationBar from './components/Navbar';
import Footer from './components/Footer';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <NavigationBar />
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/patterns" element={<Patterns />} />
          <Route path="/faqs" element={<FAQs />} />
          <Route path="/about" element={<About />} />
          <Route path="*" element={<NotFound />} /> {/* Catch-all route for non-existent URLs */}
        </Routes>
        <Footer />
      </div>
    </Router>
  );
}

export default App;