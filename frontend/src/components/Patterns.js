import React, { useEffect, useState } from 'react';
import { Container, Table } from 'react-bootstrap';
import { fetchPatterns } from '../api';
import './Patterns.css'; // Import custom CSS

const Patterns = () => {
  const [patterns, setPatterns] = useState([]);
  const [headers, setHeaders] = useState([]);

  useEffect(() => {
    const getPatterns = async () => {
      const data = await fetchPatterns();
      if (data.length > 0) {
        setHeaders(data[0].slice(1)); // Use the first row as headers, excluding the first column
        const filteredPatterns = data.slice(1).filter(row => row[0] === 'Y'); // Filter rows where the first column is 'Y'
        setPatterns(filteredPatterns.map(row => row.slice(1))); // Exclude the first column from the data
      }
    };
    getPatterns();
  }, []);

  const handleContextMenu = (event) => {
    event.preventDefault();
  };

  const parseCellContent = (cell, isLink) => {
    const urlRegex = /(https?:\/\/[^\s]+)/g;
    if (isLink) {
      // If the cell should contain a link
      return (
        <a href={cell} target="_blank" rel="noopener noreferrer">
          {cell}
        </a>
      );
    }
    const parts = cell.split(urlRegex);
    return parts.map((part, index) => {
      if (urlRegex.test(part)) {
        return (
          <a key={index} href={part} target="_blank" rel="noopener noreferrer">
            {part}
          </a>
        );
      }
      return part;
    });
  };

  return (
    <Container className="mt-5">
      <h1>Patterns</h1>
      {patterns.length > 0 ? (
        <Table striped bordered hover className="patterns-table" onContextMenu={handleContextMenu}>
          <thead className="sticky-header">
            <tr>
              {headers.map((header, index) => (
                <th key={index} className="no-wrap">{header}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {patterns.map((pattern, rowIndex) => (
              <tr key={rowIndex}>
                {pattern.map((cell, cellIndex) => (
                  <td key={cellIndex}>
                    {/* Check if the current cell is the one that contains the link */}
                    {cellIndex === 1 ? parseCellContent(cell, true) : parseCellContent(cell)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </Table>
      ) : (
        <p>No patterns found.</p>
      )}
    </Container>
  );
};

export default Patterns;
