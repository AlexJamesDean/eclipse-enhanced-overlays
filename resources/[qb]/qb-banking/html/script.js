const bankingApp = Vue.createApp({
    data() {
        return {
            isBankOpen: false,
            isATMOpen: false,
            showPinPrompt: false,
            notification: null,
            activeView: "home",
            accounts: [],
            statements: {},
            selectedAccountStatement: "checking",
            playerName: "",
            accountNumber: "",
            playerCash: 0,
            quickAmounts: [100, 500, 1000, 5000],
            selectedMoneyAccount: null,
            selectedMoneyAmount: 0,
            moneyReason: "",
            transferType: "internal",
            internalFromAccount: null,
            internalToAccount: null,
            internalTransferAmount: 0,
            externalAccountNumber: "",
            externalFromAccount: null,
            externalTransferAmount: 0,
            transferReason: "",
            debitPin: "",
            enteredPin: "",
            pinError: false,
            acceptablePins: [],
            tempBankData: null,
            createAccountName: "",
            createAccountAmount: 0,
            editAccount: null,
            editAccountName: "",
            manageAccountName: null,
            manageUserName: "",
            filteredUsers: [],
            showUsersDropdown: false,
        };
    },
    computed: {
        sortedStatements() {
            const list = this.statements[this.selectedAccountStatement] || [];
            return [...list].sort((a, b) => this.parseTimestamp(b.date) - this.parseTimestamp(a.date));
        },
        pinDots() {
            return "●".repeat(this.enteredPin.length);
        },
    },
    watch: {
        "manageAccountName.users": function () {
            this.filterUsers();
        },
    },
    methods: {
        buildAccounts(rawAccounts) {
            // the server can emit the same account twice (owner + boss/user match) — dedupe by name
            const seen = {};
            const accounts = [];
            rawAccounts.forEach((account) => {
                if (seen[account.account_name]) return;
                seen[account.account_name] = true;
                accounts.push({
                    name: account.account_name,
                    type: account.account_type,
                    balance: account.account_balance,
                    users: account.users,
                    id: account.id,
                });
            });
            return accounts;
        },
        applyPlayerData(playerData) {
            const info = playerData.charinfo || {};
            this.playerName = [info.firstname, info.lastname].filter(Boolean).join(" ");
            this.accountNumber = playerData.citizenid;
            this.playerCash = playerData.money.cash;
        },
        openBank(bankData) {
            this.applyPlayerData(bankData.playerData);
            this.accounts = this.buildAccounts(bankData.accounts);
            this.statements = {};
            Object.keys(bankData.statements).forEach((accountKey) => {
                this.statements[accountKey] = bankData.statements[accountKey].map((statement) => ({
                    id: statement.id,
                    date: statement.date,
                    reason: statement.reason,
                    amount: statement.amount,
                    type: statement.statement_type,
                    user: statement.citizenid,
                }));
            });
            this.selectedAccountStatement = "checking";
            this.selectedMoneyAccount = this.accounts[0] || null;
            this.activeView = "home";
            this.isBankOpen = true;
        },
        openATM(bankData) {
            this.applyPlayerData(bankData.playerData);
            this.accounts = this.buildAccounts(bankData.accounts);
            this.selectedMoneyAccount = this.accounts[0] || null;
            this.isATMOpen = true;
        },
        pinPrompt(enteredPin) {
            const bankData = this.tempBankData;
            if (!bankData) return;
            this.acceptablePins = Array.from(bankData.pinNumbers || []);
            if (this.acceptablePins.map(Number).includes(parseInt(enteredPin))) {
                this.showPinPrompt = false;
                this.pinError = false;
                this.enteredPin = "";
                this.openATM(bankData);
            } else {
                this.enteredPin = "";
                this.pinError = true;
                setTimeout(() => {
                    this.pinError = false;
                }, 1200);
            }
        },
        withdrawMoney(fromAtm = false) {
            if (!this.selectedMoneyAccount || this.selectedMoneyAmount <= 0) {
                return;
            }
            const amount = this.selectedMoneyAmount;
            const reason = fromAtm ? "Cashpoint Withdrawal" : this.moneyReason;
            axios
                .post("https://qb-banking/withdraw", {
                    accountName: this.selectedMoneyAccount.name,
                    amount: amount,
                    reason: reason,
                })
                .then((response) => {
                    if (response.data.success) {
                        const account = this.accounts.find((acc) => acc.name === this.selectedMoneyAccount.name);
                        if (account) {
                            account.balance -= amount;
                            this.playerCash += amount;
                            this.addStatement(this.accountNumber, account.name, reason, amount, "withdraw");
                        }
                        this.selectedMoneyAmount = 0;
                        this.moneyReason = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        depositMoney(fromAtm = false) {
            if (!this.selectedMoneyAccount || this.selectedMoneyAmount <= 0) {
                return;
            }
            const amount = this.selectedMoneyAmount;
            const reason = fromAtm ? "Cashpoint Deposit" : this.moneyReason;
            axios
                .post("https://qb-banking/deposit", {
                    accountName: this.selectedMoneyAccount.name,
                    amount: amount,
                    reason: reason,
                })
                .then((response) => {
                    if (response.data.success) {
                        const account = this.accounts.find((acc) => acc.name === this.selectedMoneyAccount.name);
                        if (account) {
                            account.balance += amount;
                            this.playerCash -= amount;
                            this.addStatement(this.accountNumber, account.name, reason, amount, "deposit");
                        }
                        this.selectedMoneyAmount = 0;
                        this.moneyReason = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        depositAllCash() {
            if (!this.selectedMoneyAccount) {
                this.addNotification("Select an account first", "error");
                return;
            }
            if (this.playerCash <= 0) {
                this.addNotification("You have no cash on you", "error");
                return;
            }
            // depositMoney reads selectedMoneyAmount, so stage the full balance through it
            this.selectedMoneyAmount = this.playerCash;
            this.depositMoney(true);
        },
        internalTransfer() {
            if (!this.internalFromAccount || !this.internalToAccount || this.internalTransferAmount <= 0) {
                return;
            }
            axios
                .post("https://qb-banking/internalTransfer", {
                    fromAccountName: this.internalFromAccount.name,
                    toAccountName: this.internalToAccount.name,
                    amount: this.internalTransferAmount,
                    reason: this.transferReason,
                })
                .then((response) => {
                    if (response.data.success) {
                        const fromAccount = this.accounts.find((acc) => acc.name === this.internalFromAccount.name);
                        if (fromAccount) {
                            fromAccount.balance -= this.internalTransferAmount;
                        }
                        const toAccount = this.accounts.find((acc) => acc.name === this.internalToAccount.name);
                        if (toAccount) {
                            toAccount.balance += this.internalTransferAmount;
                        }
                        this.addStatement(this.accountNumber, this.internalFromAccount.name, this.transferReason, this.internalTransferAmount, "withdraw");
                        this.addStatement(this.accountNumber, this.internalToAccount.name, this.transferReason, this.internalTransferAmount, "deposit");
                        this.internalTransferAmount = 0;
                        this.transferReason = "";
                        this.internalFromAccount = null;
                        this.internalToAccount = null;
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        externalTransfer() {
            if (!this.externalFromAccount || !this.externalAccountNumber || this.externalTransferAmount <= 0) {
                return;
            }
            axios
                .post("https://qb-banking/externalTransfer", {
                    fromAccountName: this.externalFromAccount.name,
                    toAccountNumber: this.externalAccountNumber,
                    amount: this.externalTransferAmount,
                    reason: this.transferReason,
                })
                .then((response) => {
                    if (response.data.success) {
                        const fromAccount = this.accounts.find((acc) => acc.name === this.externalFromAccount.name);
                        if (fromAccount) {
                            fromAccount.balance -= this.externalTransferAmount;
                        }
                        this.addStatement(this.accountNumber, this.externalFromAccount.name, this.transferReason, this.externalTransferAmount, "withdraw");
                        this.externalTransferAmount = 0;
                        this.transferReason = "";
                        this.externalFromAccount = null;
                        this.externalAccountNumber = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        orderDebitCard() {
            if (!/^\d{4}$/.test(this.debitPin)) {
                this.addNotification("PIN must be exactly 4 digits", "error");
                return;
            }
            axios
                .post("https://qb-banking/orderCard", {
                    pin: this.debitPin,
                })
                .then((response) => {
                    if (response.data.success) {
                        this.debitPin = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        openAccount() {
            if (!this.createAccountName || this.createAccountAmount < 0) {
                return;
            }
            axios
                .post("https://qb-banking/openAccount", {
                    accountName: this.createAccountName,
                    amount: this.createAccountAmount,
                })
                .then((response) => {
                    if (response.data.success) {
                        const checkingAccount = this.accounts.find((acc) => acc.name === "checking");
                        if (checkingAccount) {
                            checkingAccount.balance -= this.createAccountAmount;
                        }
                        this.accounts.push({
                            name: this.createAccountName,
                            type: "shared",
                            balance: this.createAccountAmount,
                            users: JSON.stringify([]),
                        });
                        this.addStatement(this.accountNumber, "checking", "Initial deposit for " + this.createAccountName, this.createAccountAmount, "withdraw");
                        this.addStatement(this.accountNumber, this.createAccountName, "Initial deposit", this.createAccountAmount, "deposit");
                        this.createAccountName = "";
                        this.createAccountAmount = 0;
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.createAccountName = "";
                        this.createAccountAmount = 0;
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        renameAccount() {
            if (!this.editAccount || !this.editAccountName) {
                return;
            }
            axios
                .post("https://qb-banking/renameAccount", {
                    oldName: this.editAccount.name,
                    newName: this.editAccountName,
                })
                .then((response) => {
                    if (response.data.success) {
                        const account = this.accounts.find((acc) => acc.name === this.editAccount.name);
                        if (account) {
                            account.name = this.editAccountName;
                        }
                        this.editAccount = null;
                        this.editAccountName = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        deleteAccount() {
            if (!this.editAccount) {
                return;
            }
            axios
                .post("https://qb-banking/deleteAccount", {
                    accountName: this.editAccount.name,
                })
                .then((response) => {
                    if (response.data.success) {
                        this.accounts = this.accounts.filter((acc) => acc.name !== this.editAccount.name);
                        this.editAccount = null;
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        addUserToAccount() {
            if (!this.manageAccountName || !this.manageUserName) {
                return;
            }
            axios
                .post("https://qb-banking/addUser", {
                    accountName: this.manageAccountName.name,
                    userName: this.manageUserName,
                })
                .then((response) => {
                    if (response.data.success) {
                        let usersArray = [];
                        try {
                            usersArray = JSON.parse(this.manageAccountName.users) || [];
                        } catch (e) { /* keep empty */ }
                        usersArray.push(this.manageUserName);
                        this.manageAccountName.users = JSON.stringify(usersArray);
                        this.manageUserName = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        removeUserFromAccount() {
            if (!this.manageAccountName || !this.manageUserName) {
                return;
            }
            axios
                .post("https://qb-banking/removeUser", {
                    accountName: this.manageAccountName.name,
                    userName: this.manageUserName,
                })
                .then((response) => {
                    if (response.data.success) {
                        let usersArray = [];
                        try {
                            usersArray = JSON.parse(this.manageAccountName.users) || [];
                        } catch (e) { /* keep empty */ }
                        usersArray = usersArray.filter((user) => user !== this.manageUserName);
                        this.manageAccountName.users = JSON.stringify(usersArray);
                        this.manageUserName = "";
                        this.addNotification(response.data.message, "success");
                    } else {
                        this.addNotification(response.data.message, "error");
                    }
                });
        },
        addStatement(accountNumber, accountName, reason, amount, type) {
            const newStatement = {
                date: Date.now(),
                user: accountNumber,
                reason: reason || (type === "deposit" ? "Bank Deposit" : "Bank Withdrawal"),
                amount: amount,
                type: type,
            };
            if (!this.statements[accountName]) {
                this.statements[accountName] = [];
            }
            this.statements[accountName].push(newStatement);
        },
        addNotification(message, type) {
            this.notification = {
                message: message,
                type: type,
            };
            setTimeout(() => {
                this.notification = null;
            }, 3000);
        },
        appendNumber(number) {
            if (this.enteredPin.length >= 8) return;
            this.pinError = false;
            this.enteredPin += number.toString();
        },
        backspacePin() {
            this.enteredPin = this.enteredPin.slice(0, -1);
        },
        selectAccount(account) {
            this.selectedAccountStatement = account.name;
        },
        setTransferType(type) {
            this.transferType = type;
        },
        setActiveView(view) {
            this.activeView = view;
        },
        formatCurrency(amount) {
            return new Intl.NumberFormat().format(amount || 0);
        },
        filterUsers() {
            if (!this.manageAccountName || typeof this.manageAccountName.users !== "string") {
                this.filteredUsers = [];
                return;
            }
            let usersArray;
            try {
                usersArray = JSON.parse(this.manageAccountName.users);
            } catch (e) {
                this.filteredUsers = [];
                return;
            }
            if (!Array.isArray(usersArray)) {
                this.filteredUsers = [];
                return;
            }
            if (this.manageUserName === "") {
                this.filteredUsers = usersArray;
            } else {
                this.filteredUsers = usersArray.filter((user) => user.toLowerCase().includes(this.manageUserName.toLowerCase()));
            }
        },
        selectUser(user) {
            this.manageUserName = user;
            this.showUsersDropdown = false;
        },
        hideDropdown() {
            setTimeout(() => {
                this.showUsersDropdown = false;
            }, 100);
        },
        parseTimestamp(value) {
            // statements arrive as ms numbers (runtime) or MySQL datetime strings (boot load)
            if (typeof value === "number") return value;
            if (typeof value === "string") {
                if (/^\d+$/.test(value)) return parseInt(value);
                const parsed = Date.parse(value.replace(" ", "T"));
                if (!isNaN(parsed)) return parsed;
            }
            return 0;
        },
        formatDate(timestamp) {
            const ms = this.parseTimestamp(timestamp);
            if (!ms) return "—";
            const date = new Date(ms);
            const day = date.getDate().toString().padStart(2, "0");
            const month = (date.getMonth() + 1).toString().padStart(2, "0");
            const year = date.getFullYear();
            const hours = date.getHours().toString().padStart(2, "0");
            const minutes = date.getMinutes().toString().padStart(2, "0");
            return `${day}/${month}/${year} ${hours}:${minutes}`;
        },
        balanceClass(statementType) {
            return statementType === "deposit" ? "positive-balance" : "negative-balance";
        },
        handleMessage(event) {
            const action = event.data.action;
            if (action === "openBank") {
                this.openBank(event.data);
            } else if (action === "openATM") {
                this.tempBankData = event.data;
                this.enteredPin = "";
                this.pinError = false;
                this.showPinPrompt = true;
            }
        },
        handleKeydown(event) {
            if (this.showPinPrompt) {
                if (/^[0-9]$/.test(event.key)) {
                    this.appendNumber(event.key);
                    return;
                }
                if (event.key === "Backspace") {
                    this.backspacePin();
                    return;
                }
                if (event.key === "Enter") {
                    this.pinPrompt(this.enteredPin);
                    return;
                }
            }
            if (event.key === "Escape") {
                this.closeApplication();
            }
        },
        closeApplication() {
            this.isBankOpen = false;
            this.isATMOpen = false;
            this.showPinPrompt = false;
            this.enteredPin = "";
            this.pinError = false;
            this.acceptablePins = [];
            this.tempBankData = null;
            this.notification = null;
            this.activeView = "home";
            axios.post(`https://${GetParentResourceName()}/closeApp`, {});
        },
    },
    mounted() {
        document.addEventListener("keydown", this.handleKeydown);
        window.addEventListener("message", this.handleMessage);
    },
    beforeUnmount() {
        document.removeEventListener("keydown", this.handleKeydown);
    },
}).mount("#app");
