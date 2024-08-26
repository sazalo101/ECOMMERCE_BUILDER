import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Route, Routes, Link, useNavigate, useParams } from 'react-router-dom';
import { AuthClient } from '@dfinity/auth-client';
import { ECommerceAPI_backend } from 'declarations/ECommerceAPI_backend';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Button from '@mui/material/Button';
import Container from '@mui/material/Container';
import Box from '@mui/material/Box';
import List from '@mui/material/List';
import ListItem from '@mui/material/ListItem';
import ListItemText from '@mui/material/ListItemText';
import TextField from '@mui/material/TextField';
import Select from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import { motion } from 'framer-motion';

const IDENTITY_URL = 'https://identity.ic0.app/#authorize';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#90caf9',
    },
    secondary: {
      main: '#f48fb1',
    },
  },
});

const MotionContainer = motion(Container);
const MotionBox = motion(Box);

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <div className="App">
          <AppBar position="static">
            <Toolbar>
              <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
                E-Commerce API Dashboard
              </Typography>
              <Button color="inherit" component={Link} to="/">Home</Button>
              <Button color="inherit" component={Link} to="/stores">Stores</Button>
              <Button color="inherit" component={Link} to="/categories">Categories</Button>
              <Button color="inherit" component={Link} to="/account">Account</Button>
            </Toolbar>
          </AppBar>

          <MotionContainer
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/stores" element={<ProtectedRoute component={StoreList} />} />
              <Route path="/store/:storeId" element={<ProtectedRoute component={StorePage} />} />
              <Route path="/categories" element={<ProtectedRoute component={CategoryList} />} />
              <Route path="/account" element={<ProtectedRoute component={AccountPage} />} />
            </Routes>
          </MotionContainer>
        </div>
      </Router>
    </ThemeProvider>
  );
}

function Home() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [identity, setIdentity] = useState(null);
  const [apiKey, setApiKey] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const init = async () => {
      const authClient = await AuthClient.create();
      const isAuthenticated = await authClient.isAuthenticated();
      setIsAuthenticated(isAuthenticated);

      if (isAuthenticated) {
        const identity = await authClient.getIdentity();
        setIdentity(identity);
        await initializeUser(identity);
      }
    };

    init();
  }, []);

  const initializeUser = async (identity) => {
    try {
      const principal = identity.getPrincipal().toText();
      const apiKey = await ECommerceAPI_backend.createUser(principal, "User");
      setApiKey(apiKey);
      localStorage.setItem('apiKey', apiKey);
    } catch (error) {
      console.error('User initialization error:', error);
    }
  };

  const handleLogin = async () => {
    try {
      const authClient = await AuthClient.create();
      await authClient.login({
        identityProvider: IDENTITY_URL,
        onSuccess: async () => {
          const identity = await authClient.getIdentity();
          setIdentity(identity);
          setIsAuthenticated(true);
          await initializeUser(identity);
        },
      });
    } catch (error) {
      console.error('Login error:', error);
    }
  };

  const handleLogout = async () => {
    try {
      const authClient = await AuthClient.create();
      await authClient.logout();
      setIsAuthenticated(false);
      setIdentity(null);
      setApiKey('');
      localStorage.removeItem('apiKey');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  return (
    <MotionBox
      sx={{ mt: 4 }}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      <Typography variant="h4" gutterBottom>E-Commerce API Dashboard</Typography>
      {!isAuthenticated ? (
        <Button variant="contained" onClick={handleLogin}>Login with Internet Identity</Button>
      ) : (
        <Box>
          <Typography variant="body1" gutterBottom>Welcome, {identity.getPrincipal().toText()}</Typography>
          <Button variant="contained" onClick={handleLogout} sx={{ mr: 1 }}>Logout</Button>
          <Button variant="contained" onClick={() => navigate('/stores')} sx={{ mr: 1 }}>Manage Stores</Button>
          <Button variant="contained" onClick={() => navigate('/categories')} sx={{ mr: 1 }}>Manage Categories</Button>
          <Button variant="contained" onClick={() => navigate('/account')}>My Account</Button>
        </Box>
      )}
    </MotionBox>
  );
}

function ProtectedRoute({ component: Component }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const checkAuth = async () => {
      const authClient = await AuthClient.create();
      const isAuthenticated = await authClient.isAuthenticated();
      setIsAuthenticated(isAuthenticated);
      setLoading(false);

      if (!isAuthenticated) {
        navigate('/');
      }
    };

    checkAuth();
  }, [navigate]);

  if (loading) {
    return <Typography>Loading...</Typography>;
  }

  return isAuthenticated ? <Component /> : null;
}

function StoreList() {
  const [stores, setStores] = useState([]);
  const [newStoreName, setNewStoreName] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    fetchStores();
  }, []);

  const fetchStores = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.listStores(apiKey);
      if ('ok' in result) {
        setStores(result.ok);
      } else {
        console.error(result.err);
      }
    } catch (error) {
      console.error('Fetch stores error:', error);
    }
  };

  const handleCreateStore = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.createStore(apiKey, newStoreName);
      if ('ok' in result) {
        alert('Store created successfully');
        setNewStoreName('');
        fetchStores();
      } else {
        console.error(result.err);
        alert('Error creating store');
      }
    } catch (error) {
      console.error('Create store error:', error);
    }
  };

  return (
    <MotionBox
      sx={{ mt: 4 }}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <Typography variant="h4" gutterBottom>My Stores</Typography>
      <List>
        {stores.map((store) => (
          <ListItem key={store.id}>
            <ListItemText primary={store.name} />
            <Button variant="outlined" onClick={() => navigate(`/store/${store.id}`)}>Manage</Button>
          </ListItem>
        ))}
      </List>
      <Box sx={{ mt: 2 }}>
        <TextField
          label="New Store Name"
          variant="outlined"
          value={newStoreName}
          onChange={(e) => setNewStoreName(e.target.value)}
          sx={{ mr: 1 }}
        />
        <Button variant="contained" onClick={handleCreateStore}>Create Store</Button>
      </Box>
    </MotionBox>
  );
}

function StorePage() {
  const { storeId } = useParams();
  const [products, setProducts] = useState([]);
  const [newProduct, setNewProduct] = useState({ name: '', price: '', inventory: '', categoryId: '' });
  const [categories, setCategories] = useState([]);

  useEffect(() => {
    fetchProducts();
    fetchCategories();
  }, [storeId]);

  const fetchProducts = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.listProducts(apiKey, storeId, 0, 100);
      if ('ok' in result) {
        setProducts(result.ok);
      } else {
        console.error(result.err);
      }
    } catch (error) {
      console.error('Fetch products error:', error);
    }
  };

  const fetchCategories = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.listCategories(apiKey);
      if ('ok' in result) {
        setCategories(result.ok);
      } else {
        console.error(result.err);
      }
    } catch (error) {
      console.error('Fetch categories error:', error);
    }
  };

  const handleAddProduct = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.addProduct(
        apiKey,
        storeId,
        newProduct.name,
        parseInt(newProduct.price),
        parseInt(newProduct.inventory),
        newProduct.categoryId ? [parseInt(newProduct.categoryId)] : []
      );
      if ('ok' in result) {
        alert('Product added successfully');
        setNewProduct({ name: '', price: '', inventory: '', categoryId: '' });
        fetchProducts();
      } else {
        console.error(result.err);
        alert('Error adding product');
      }
    } catch (error) {
      console.error('Add product error:', error);
    }
  };

  return (
    <MotionBox
      sx={{ mt: 4 }}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <Typography variant="h4" gutterBottom>Store: {storeId}</Typography>
      <Typography variant="h5" gutterBottom>Products</Typography>
      <List>
        {products.map((product) => (
          <ListItem key={product.id}>
            <ListItemText 
              primary={product.name} 
              secondary={`Price: ${product.price}, Inventory: ${product.inventory}`} 
            />
          </ListItem>
        ))}
      </List>
      <Typography variant="h5" gutterBottom>Add New Product</Typography>
      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, maxWidth: 400 }}>
        <TextField
          label="Product Name"
          variant="outlined"
          value={newProduct.name}
          onChange={(e) => setNewProduct({ ...newProduct, name: e.target.value })}
        />
        <TextField
          label="Price"
          variant="outlined"
          type="number"
          value={newProduct.price}
          onChange={(e) => setNewProduct({ ...newProduct, price: e.target.value })}
        />
        <TextField
          label="Inventory"
          variant="outlined"
          type="number"
          value={newProduct.inventory}
          onChange={(e) => setNewProduct({ ...newProduct, inventory: e.target.value })}
        />
        <Select
          value={newProduct.categoryId}
          onChange={(e) => setNewProduct({ ...newProduct, categoryId: e.target.value })}
          displayEmpty
        >
          <MenuItem value="">
            <em>Select Category</em>
          </MenuItem>
          {categories.map((category) => (
            <MenuItem key={category.id} value={category.id}>
              {category.name}
            </MenuItem>
          ))}
        </Select>
        <Button variant="contained" onClick={handleAddProduct}>Add Product</Button>
      </Box>
    </MotionBox>
  );
}

function CategoryList() {
  const [categories, setCategories] = useState([]);
  const [newCategoryName, setNewCategoryName] = useState('');

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.listCategories(apiKey);
      if ('ok' in result) {
        setCategories(result.ok);
      } else {
        console.error(result.err);
      }
    } catch (error) {
      console.error('Fetch categories error:', error);
    }
  };

  const handleCreateCategory = async () => {
    try {
      const apiKey = localStorage.getItem('apiKey');
      const result = await ECommerceAPI_backend.createCategory(apiKey, newCategoryName);
      if ('ok' in result) {
        alert('Category created successfully');
        setNewCategoryName('');
        fetchCategories();
      } else {
        console.error(result.err);
        alert('Error creating category');
      }
    } catch (error) {
      console.error('Create category error:', error);
    }
  };

  return (
    <MotionBox
      sx={{ mt: 4 }}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      <Typography variant="h4" gutterBottom>Categories</Typography>
      <List>
        {categories.map((category) => (
          <ListItem key={category.id}>
            <ListItemText primary={category.name} />
          </ListItem>
        ))}
      </List>
      <Box sx={{ mt: 2 }}>
        <TextField
          label="New Category Name"
          variant="outlined"
          value={newCategoryName}
          onChange={(e) => setNewCategoryName(e.target.value)}
          sx={{ mr: 1 }}
        />
        <Button variant="contained" onClick={handleCreateCategory}>Create Category</Button>
      </Box>
    </MotionBox>
  );
}

function AccountPage() {
    const [userInfo, setUserInfo] = useState(null);
  
    useEffect(() => {
      fetchUserInfo();
    }, []);
  
    const fetchUserInfo = async () => {
      try {
        const apiKey = localStorage.getItem('apiKey');
        const result = await ECommerceAPI_backend.getUserInfo(apiKey);
        if ('ok' in result) {
          setUserInfo(result.ok);
        } else {
          console.error(result.err);
        }
      } catch (error) {
        console.error('Fetch user info error:', error);
      }
    };
  
    return (
      <MotionBox
        sx={{ mt: 4 }}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <Typography variant="h4" gutterBottom>My Account</Typography>
        {userInfo ? (
          <Card>
            <CardContent>
              <Typography variant="body1">Principal ID: {userInfo.principal}</Typography>
              <Typography variant="body1">Username: {userInfo.username}</Typography>
              <Typography variant="body1">Account Created: {new Date(userInfo.created_at).toLocaleString()}</Typography>
            </CardContent>
          </Card>
        ) : (
          <Typography variant="body1">Loading user info...</Typography>
        )}
      </MotionBox>
    );
  }
  
  export default App;