import React from 'react';
import { Container, Card } from 'react-bootstrap';

const Home = () => {
  return (
    <Container className="mt-5">
      <Card>
        <Card.Body>
          <Card.Title>Welcome to the Home Page</Card.Title>
          <Card.Text>
            This is a simple hero unit, a simple jumbotron-style component for calling extra attention to featured content or information.
          </Card.Text>
        </Card.Body>
      </Card>
    </Container>
  );
};

export default Home;