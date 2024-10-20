import React, { useEffect, useState } from 'react';
import { Container, ListGroup } from 'react-bootstrap';
import { fetchPatterns } from '../api';

const Patterns = () => {
  const [patterns, setPatterns] = useState([]);

  useEffect(() => {
    const getPatterns = async () => {
      const data = await fetchPatterns();
      setPatterns(data);
    };
    getPatterns();
  }, []);

  return (
    <Container>
      <h1>Patterns</h1>
      {patterns.length > 0 ? (
        <ListGroup>
          {patterns.map((pattern, index) => (
            <ListGroup.Item key={index}>{pattern}</ListGroup.Item>
          ))}
        </ListGroup>
      ) : (
        <p>No patterns found.</p>
      )}
    </Container>
  );
};

export default Patterns;