import React from 'react';
import { Container, Row, Col } from 'react-bootstrap';

const Footer = () => {
  const currentYear = new Date().getFullYear();
  const siteName = "Cool Sewing Stuff"; // Replace with your actual site name

  return (
    <footer className="bg-light text-center text-lg-start">
      <Container className="p-4">
        <Row>
          <Col lg={6} md={12} className="mb-4 mb-md-0">
            <h5 className="text-uppercase">About Us</h5>
            <p>
              Learn more about our company and team. We are dedicated to providing the best service possible.
            </p>
          </Col>
          <Col lg={6} md={12} className="mb-4 mb-md-0">
            <h5 className="text-uppercase">Contact Us</h5>
            <p>
              You can reach us at contact@coolsewingstuff.com or call us at (123) 456-7890.
            </p>
          </Col>
        </Row>
      </Container>
      <div className="text-center p-3 bg-dark text-white">
        © {currentYear} {siteName}. All rights reserved.
      </div>
    </footer>
  );
};

export default Footer;