import React from 'react';
import { Link } from 'react-router-dom';

const Footer = () => {
  const currentYear = new Date().getFullYear();
  const siteName = "Cool Sewing Stuff"; // Replace with your actual site name

  return (
    <footer className="bg-light text-center text-lg-start mt-5">
      <div className="text-center p-3 bg-dark text-white d-flex justify-content-between">
        <div>
          © {currentYear} {siteName}. All rights reserved.
        </div>
        <div>
          <Link to="/about" className="text-white mx-2">About Us</Link>
          <Link to="/faqs" className="text-white mx-2">FAQs</Link>
        </div>
      </div>
    </footer>
  );
};

export default Footer;