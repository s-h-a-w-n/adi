export const fetchPatterns = async () => {
  try {
    const response = await fetch('http://localhost:3001/patterns');
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const data = await response.json();
    console.log('Fetched data:', data);
    return data;
  } catch (error) {
    console.error('Error fetching data:', error);
    return [];
  }
};