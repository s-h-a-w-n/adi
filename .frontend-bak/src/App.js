import React from 'react';
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';
import Home from './components/Home';
import Patterns from './components/Patterns';
import FAQs from './components/FAQs';
import About from './components/About';
import SimplePage from './components/SimplePage';
import NotFound from './components/NotFound'; // Import NotFound component
import NavigationBar from './components/Navbar';
import Footer from './components/Footer';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <NavigationBar />
        <Switch>
          <Route path="/" exact component={Home} />
          <Route path="/patterns" component={Patterns} />
          <Route path="/faqs" component={FAQs} />
          <Route path="/about" component={About} />
          <Route path="/simple" component={SimplePage} />
          <Route component={NotFound} /> {/* Catch-all route for non-existent URLs */}
        </Switch>
        <Footer />
      </div>
    </Router>
  );
}

export default App;