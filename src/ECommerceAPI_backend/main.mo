import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import List "mo:base/List";

actor ECommerceAPI {
    type ProductId = Nat;
    type UserId = Text;
    type OrderId = Nat;
    type ApiKey = Text;
    type StoreId = Text;
    type CategoryId = Nat;

    type Product = {
        id: ProductId;
        storeId: StoreId;
        name: Text;
        price: Nat;
        inventory: Nat;
        categoryId: ?CategoryId;
    };

    type User = {
        id: UserId;
        name: Text;
        balance: Nat;
        apiKey: ApiKey;
    };

    type Store = {
        id: StoreId;
        ownerId: UserId;
        name: Text;
    };

    type Order = {
        id: OrderId;
        userId: UserId;
        productId: ProductId;
        quantity: Nat;
        status: Text;
    };

    type Category = {
        id: CategoryId;
        name: Text;
        description: Text;
    };

    type CustomerAccount = {
        userId: UserId;
        wishlist: List.List<ProductId>;
        savedAddresses: List.List<Text>;
        orderHistory: List.List<OrderId>;
    };

    type Error = {
        #NotFound;
        #InsufficientFunds;
        #InsufficientInventory;
        #Unauthorized;
    };

    private var nextProductId: Nat = 0;
    private var nextOrderId: Nat = 0;
    private var nextCategoryId: Nat = 0;
    private let products = HashMap.HashMap<ProductId, Product>(0, Nat.equal, Hash.hash);
    private let users = HashMap.HashMap<UserId, User>(0, Text.equal, Text.hash);
    private let orders = HashMap.HashMap<OrderId, Order>(0, Nat.equal, Hash.hash);
    private let apiKeys = HashMap.HashMap<ApiKey, UserId>(0, Text.equal, Text.hash);
    private let productLinks = HashMap.HashMap<Text, ProductId>(0, Text.equal, Text.hash);
    private let storeLinks = HashMap.HashMap<Text, StoreId>(0, Text.equal, Text.hash);
    private let stores = HashMap.HashMap<StoreId, Store>(0, Text.equal, Text.hash);
    private let categories = HashMap.HashMap<CategoryId, Category>(0, Nat.equal, Hash.hash);
    private let customerAccounts = HashMap.HashMap<UserId, CustomerAccount>(0, Text.equal, Text.hash);

    private var seed: Nat = 123456789;
    private func random(): Nat {
        seed := (seed * 1103515245 + 12345) % (2 ** 32);
        seed
    };

    private func generateApiKey(): ApiKey {
        let timestamp = Int.abs(Time.now());
        let randomPart = random();
        Text.concat(Nat.toText(timestamp), Nat.toText(randomPart))
    };

    private func validateApiKey(key: ApiKey): Bool {
        Option.isSome(apiKeys.get(key))
    };

    private func generateStoreId(ownerId: UserId, name: Text): StoreId {
        Text.concat(ownerId, Text.concat("-", name))
    };

    private func generateStoreLink(storeId: StoreId): Text {
        let timestamp = Int.abs(Time.now());
        let randomPart = random();
        Text.concat("store-", Text.concat(storeId, Text.concat("-", Text.concat(Nat.toText(timestamp), Nat.toText(randomPart)))))
    };

    private func getOwnerIdFromApiKey(apiKey: ApiKey): UserId {
        Option.unwrap(apiKeys.get(apiKey))
    };

    private func generateProductLink(productId: ProductId): Text {
        let timestamp = Int.abs(Time.now());
        let randomPart = random();
        Text.concat("product-", Text.concat(Nat.toText(productId), Text.concat("-", Text.concat(Nat.toText(timestamp), Nat.toText(randomPart)))))
    };

    public func createUser(id: UserId, name: Text): async ApiKey {
        let apiKey = generateApiKey();
        let user: User = {
            id = id;
            name = name;
            balance = 0;
            apiKey = apiKey;
        };
        users.put(id, user);
        apiKeys.put(apiKey, id);
        apiKey
    };

    public func createStore(apiKey: ApiKey, name: Text): async Result.Result<(StoreId, Text), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        let storeId = generateStoreId(ownerId, name);
        let storeLink = generateStoreLink(storeId);
        let store: Store = {
            id = storeId;
            ownerId = ownerId;
            name = name;
        };
        stores.put(storeId, store);
        storeLinks.put(storeLink, storeId);
        #ok((storeId, storeLink))
    };

    public func addProduct(apiKey: ApiKey, storeId: StoreId, name: Text, price: Nat, inventory: Nat, categoryId: ?CategoryId): async Result.Result<Text, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (stores.get(storeId)) {
            case (null) { #err(#NotFound) };
            case (?store) {
                if (store.ownerId != ownerId) {
                    return #err(#Unauthorized);
                };
                let id = nextProductId;
                nextProductId += 1;
                let product: Product = {
                    id = id;
                    storeId = storeId;
                    name = name;
                    price = price;
                    inventory = inventory;
                    categoryId = categoryId;
                };
                products.put(id, product);
                let productLink = generateProductLink(id);
                productLinks.put(productLink, id);
                #ok(productLink)
            };
        }
    };

    public query func getProduct(apiKey: ApiKey, storeId: StoreId, id: ProductId): async Result.Result<Product, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (stores.get(storeId)) {
            case (null) { #err(#NotFound) };
            case (?store) {
                if (store.ownerId != ownerId) {
                    return #err(#Unauthorized);
                };
                switch (products.get(id)) {
                    case (null) { #err(#NotFound) };
                    case (?product) { #ok(product) };
                }
            };
        }
    };

    public query func getProductByLink(apiKey: ApiKey, storeId: StoreId, link: Text): async Result.Result<Product, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (stores.get(storeId)) {
            case (null) { #err(#NotFound) };
            case (?store) {
                if (store.ownerId != ownerId) {
                    return #err(#Unauthorized);
                };
                switch (productLinks.get(link)) {
                    case (null) { #err(#NotFound) };
                    case (?productId) {
                        switch (products.get(productId)) {
                            case (null) { #err(#NotFound) };
                            case (?product) { #ok(product) };
                        }
                    };
                }
            };
        }
    };

    public query func getStoreLink(apiKey: ApiKey, storeId: StoreId): async Result.Result<Text, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (stores.get(storeId)) {
            case (null) { #err(#NotFound) };
            case (?store) {
                if (store.ownerId != ownerId) {
                    return #err(#Unauthorized);
                };
                let storeLink = generateStoreLink(storeId);
                storeLinks.put(storeLink, storeId);
                #ok(storeLink)
            };
        }
    };

    public func getStoreByLink(apiKey: ApiKey, link: Text): async Result.Result<Store, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (storeLinks.get(link)) {
            case (null) { #err(#NotFound) };
            case (?storeId) {
                switch (stores.get(storeId)) {
                    case (null) { #err(#NotFound) };
                    case (?store) {
                        if (store.ownerId != ownerId) {
                            return #err(#Unauthorized);
                        };
                        #ok(store)
                    };
                }
            };
        }
    };

    public func addUserBalance(apiKey: ApiKey, userId: UserId, amount: Nat): async Result.Result<(), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (users.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?user) {
                let updatedUser: User = {
                    id = user.id;
                    name = user.name;
                    balance = user.balance + amount;
                    apiKey = user.apiKey;
                };
                users.put(userId, updatedUser);
                #ok(())
            };
        }
    };

    public func createOrder(apiKey: ApiKey, userId: UserId, productId: ProductId, quantity: Nat): async Result.Result<OrderId, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (users.get(userId), products.get(productId), customerAccounts.get(userId)) {
            case (?user, ?product, ?account) {
                if (product.inventory < quantity) {
                    return #err(#InsufficientInventory);
                };
                if (user.balance < product.price * quantity) {
                    return #err(#InsufficientFunds);
                };
                let orderId = nextOrderId;
                nextOrderId += 1;
                let order: Order = {
                    id = orderId;
                    userId = userId;
                    productId = productId;
                    quantity = quantity;
                    status = "Pending";
                };
                orders.put(orderId, order);

                let updatedProduct: Product = {
                    id = product.id;
                    storeId = product.storeId;
                    name = product.name;
                    price = product.price;
                    inventory = product.inventory - quantity;
                    categoryId = product.categoryId;
                };
                products.put(productId, updatedProduct);

                let updatedUser: User = {
                    id = user.id;
                    name = user.name;
                    balance = user.balance - (product.price * quantity);
                    apiKey = user.apiKey;
                };
                users.put(userId, updatedUser);

                let updatedOrderHistory = List.push(orderId, account.orderHistory);
                let updatedAccount: CustomerAccount = {
                    userId = account.userId;
                    wishlist = account.wishlist;
                    savedAddresses = account.savedAddresses;
                    orderHistory = updatedOrderHistory;
                };
                customerAccounts.put(userId, updatedAccount);

                #ok(orderId)
            };
            case _ { #err(#NotFound) };
        }
    };

    public query func getOrder(apiKey: ApiKey, id: OrderId): async Result.Result<Order, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (orders.get(id)) {
            case (null) { #err(#NotFound) };
            case (?order) { #ok(order) };
        }
    };

    public query func listProducts(apiKey: ApiKey, storeId: StoreId, start: Nat, limit: Nat): async Result.Result<[Product], Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (stores.get(storeId)) {
            case (null) { #err(#NotFound) };
            case (?store) {
                if (store.ownerId != ownerId) {
                    return #err(#Unauthorized);
                };
                let productArray = Iter.toArray(products.vals());
                let filteredProducts = Array.filter(productArray, func (p: Product): Bool { p.storeId == storeId });
                let size = filteredProducts.size();
                let end = if (start + limit > size) { size } else { start + limit };
                #ok(Array.subArray(filteredProducts, start, end - start))
            };
        }
    };

    public query func getProductLink(apiKey: ApiKey, storeId: StoreId, productId: ProductId): async Result.Result<Text, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        switch (stores.get(storeId)) {
            case (null) { #err(#NotFound) };
            case (?store) {
                if (store.ownerId != ownerId) {
                    return #err(#Unauthorized);
                };
                switch (products.get(productId)) {
                    case (null) { #err(#NotFound) };
                    case (?product) {
                        for ((link, id) in productLinks.entries()) {
                            if (id == productId) {
                                return #ok(link);
                            };
                        };
                        #err(#NotFound)
                    };
                }
            };
        }
    };

    public query func getUserBalance(apiKey: ApiKey, userId: UserId): async Result.Result<Nat, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (users.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?user) { #ok(user.balance) };
        }
    };

    public query func listStores(apiKey: ApiKey): async Result.Result<[Store], Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let ownerId = getOwnerIdFromApiKey(apiKey);
        let storeArray = Iter.toArray(stores.vals());
        let filteredStores = Array.filter(storeArray, func (s: Store): Bool { s.ownerId == ownerId });
        #ok(filteredStores)
    };

    // Category management functions
    public func createCategory(apiKey: ApiKey, name: Text, description: Text): async Result.Result<CategoryId, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let id = nextCategoryId;
        nextCategoryId += 1;
        let category: Category = {
            id = id;
            name = name;
            description = description;
        };
        categories.put(id, category);
        #ok(id)
    };

    public query func getCategory(apiKey: ApiKey, id: CategoryId): async Result.Result<Category, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (categories.get(id)) {
            case (null) { #err(#NotFound) };
            case (?category) { #ok(category) };
        }
    };

    public func updateCategory(apiKey: ApiKey, id: CategoryId, name: Text, description: Text): async Result.Result<(), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (categories.get(id)) {
            case (null) { #err(#NotFound) };
            case (?category) {
                let updatedCategory: Category = {
                    id = id;
                    name = name;
                    description = description;
                };
                categories.put(id, updatedCategory);
                #ok(())
            };
        }
    };

    public func deleteCategory(apiKey: ApiKey, id: CategoryId): async Result.Result<(), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (categories.get(id)) {
            case (null) { #err(#NotFound) };
            case (?category) {
                categories.delete(id);
                #ok(())
            };
        }
    };

    public query func listCategories(apiKey: ApiKey): async Result.Result<[Category], Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        let categoryArray = Iter.toArray(categories.vals());
        #ok(categoryArray)
    };

    // Customer account functions
    public func createCustomerAccount(apiKey: ApiKey, userId: UserId): async Result.Result<(), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (?_) { #err(#Unauthorized) }; // Account already exists
            case (null) {
                let account: CustomerAccount = {
                    userId = userId;
                    wishlist = List.nil<ProductId>();
                    savedAddresses = List.nil<Text>();
                    orderHistory = List.nil<OrderId>();
                };
                customerAccounts.put(userId, account);
                #ok(())
            };
        }
    };

    public func addToWishlist(apiKey: ApiKey, userId: UserId, productId: ProductId): async Result.Result<(), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?account) {
                let updatedWishlist = List.push(productId, account.wishlist);
                let updatedAccount: CustomerAccount = {
                    userId = account.userId;
                    wishlist = updatedWishlist;
                    savedAddresses = account.savedAddresses;
                    orderHistory = account.orderHistory;
                };
                customerAccounts.put(userId, updatedAccount);
                #ok(())
            };
        }
    };

    public func addSavedAddress(apiKey: ApiKey, userId: UserId, address: Text): async Result.Result<(), Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?account) {
                let updatedAddresses = List.push(address, account.savedAddresses);
                let updatedAccount: CustomerAccount = {
                    userId = account.userId;
                    wishlist = account.wishlist;
                    savedAddresses = updatedAddresses;
                    orderHistory = account.orderHistory;
                };
                customerAccounts.put(userId, updatedAccount);
                #ok(())
            };
        }
    };

    public query func getCustomerAccount(apiKey: ApiKey, userId: UserId): async Result.Result<CustomerAccount, Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?account) { #ok(account) };
        }
    };

    public query func getWishlist(apiKey: ApiKey, userId: UserId): async Result.Result<[ProductId], Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?account) { #ok(List.toArray(account.wishlist)) };
        }
    };

    public query func getSavedAddresses(apiKey: ApiKey, userId: UserId): async Result.Result<[Text], Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?account) { #ok(List.toArray(account.savedAddresses)) };
        }
    };

    public query func getOrderHistory(apiKey: ApiKey, userId: UserId): async Result.Result<[OrderId], Error> {
        if (not validateApiKey(apiKey)) {
            return #err(#Unauthorized);
        };
        switch (customerAccounts.get(userId)) {
            case (null) { #err(#NotFound) };
            case (?account) { #ok(List.toArray(account.orderHistory)) };
        }
    };
};