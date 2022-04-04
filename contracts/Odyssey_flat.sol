//     ____      __                              _    __           __
//    / __ \____/ /_  _______________  __  __   | |  / /__  ____  / /___  __________
//   / / / / __  / / / / ___/ ___/ _ \/ / / /   | | / / _ \/ __ \/ __/ / / / ___/ _ \
//  / /_/ / /_/ / /_/ (__  |__  )  __/ /_/ /    | |/ /  __/ / / / /_/ /_/ / /  /  __/
//  \____/\__,_/\__, /____/____/\___/\__, /     |___/\___/_/ /_/\__/\__,_/_/   \___/
//             /____/               /____/
//
// https://odysseyventure.com/

pragma solidity 0.8.11;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

library SafeMathInt {
  int256 private constant MIN_INT256 = int256(1) << 255;
  int256 private constant MAX_INT256 = ~(int256(1) << 255);

  function mul(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a * b;
    require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
    require((b == 0) || (c / b == a));
    return c;
  }

  function div(int256 a, int256 b) internal pure returns (int256) {
    require(b != -1 || a != MIN_INT256);
    return a / b;
  }

  function sub(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a - b;
    require((b >= 0 && c <= a) || (b < 0 && c > a));
    return c;
  }

  function add(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a + b;
    require((b >= 0 && c >= a) || (b < 0 && c < a));
    return c;
  }

  function abs(int256 a) internal pure returns (int256) {
    require(a != MIN_INT256);
    return a < 0 ? -a : a;
  }

  function toUint256Safe(int256 a) internal pure returns (uint256) {
    require(a >= 0);
    return uint256(a);
  }
}

library SafeMathUint {
  function toInt256Safe(uint256 a) internal pure returns (int256) {
    int256 b = int256(a);
    require(b >= 0);
    return b;
  }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Spend `amount` form the allowance of `owner` toward `spender`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract RewardsTracker is Ownable {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  uint256 public totalBalance = 0;
  uint256 public totalDistributed = 0;
  uint256 internal magnifiedBalance;
  uint256 constant internal MAGNIFIER = 2**128;

  mapping(address => uint256) public balanceOf;
  mapping(address => int256) internal magnifiedCorrections;
  mapping(address => uint256) internal withdrawnRewards;

  event FundsDeposited(address indexed from, uint amount);
  event FundsWithdrawn(address indexed account, uint amount);

  constructor() { }

  receive() external payable {
    require(msg.value > 0, "No funds sent");
    require(totalBalance > 0, "No balances tracked");

    distributeFunds(msg.value);
    emit FundsDeposited(msg.sender, msg.value);
  }

  function getAccumulated(address account) public view returns(uint256) {
    return magnifiedBalance.mul(balanceOf[account]).toInt256Safe().add(magnifiedCorrections[account]).toUint256Safe() / MAGNIFIER;
  }

  function getPending(address account) public view returns(uint256) {
    return getAccumulated(account).sub(withdrawnRewards[account]);
  }

  function getWithdrawn(address account) external view returns(uint256) {
    return withdrawnRewards[account];
  }

  function putBalance(address account, uint256 newBalance) public virtual onlyOwner {
    uint256 currentBalance = balanceOf[account];
    balanceOf[account] = newBalance;
    if (newBalance > currentBalance) {
      uint256 increaseAmount = newBalance.sub(currentBalance);
      increaseBalance(account, increaseAmount);
      totalBalance += increaseAmount;
    } else if(newBalance < currentBalance) {
      uint256 reduceAmount = currentBalance.sub(newBalance);
      decreaseBalance(account, reduceAmount);
      totalBalance -= reduceAmount;
    }
  }

  function withdrawFunds(address payable account) public virtual {
    uint256 amount = processWithdraw(account);
    if (amount > 0) emit FundsWithdrawn(account, amount);
  }

  // PRIVATE

  function decreaseBalance(address account, uint256 amount) internal {
    magnifiedCorrections[account] = magnifiedCorrections[account].add((magnifiedBalance.mul(amount)).toInt256Safe());
  }

  function distributeFunds(uint256 amount) internal virtual {
    if (totalBalance > 0 && amount > 0) {
      magnifiedBalance = magnifiedBalance.add((amount).mul(MAGNIFIER) / totalBalance);
      totalDistributed = totalDistributed.add(amount);
    }
  }

  function increaseBalance(address account, uint256 amount) internal {
    magnifiedCorrections[account] = magnifiedCorrections[account].sub((magnifiedBalance.mul(amount)).toInt256Safe());
  }

  function processWithdraw(address payable account) internal returns (uint256) {
    uint256 amount = getPending(account);
    if (amount <= 0) return 0;
    withdrawnRewards[account] = withdrawnRewards[account].add(amount);
    (bool success,) = account.call{value: amount, gas: 3000}("");
    if (!success) {
      withdrawnRewards[account] = withdrawnRewards[account].sub(amount);
      return 0;
    }
    return amount;
  }
}

contract OdysseyRewards is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;

  string public name;
  string public symbol;

  struct Holder {
    uint256 index;
    uint256 tokens;
    uint32 added;
    uint32 bought;
    uint32 claimed;
    uint32 excluded;
    uint32 sold;
    uint32 percent;
  }

  uint256 public holders = 0;
  uint256 public currentHolder = 0;
  mapping (uint256 => address) public holderAt;
  mapping (address => Holder) public holder;

  uint256 public minimumBalance = 15_000_000 ether; // must hold 15,000,000+ tokens
  uint256 public waitingPeriod = 6 hours;
  bool public isStakingOn = false;
  uint256 public totalTracked = 0;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastRecord, uint256 gasUsed);
  event ExcludedChanged(address indexed account, bool excluded);
  event MinimumBalanceChanged(uint256 from, uint256 to);
  event StakingChanged(bool from, bool to);
  event WaitingPeriodChanged(uint256 from, uint256 to);

  constructor(string memory name_, string memory symbol_) RewardsTracker() {
    name = name_;
    symbol = symbol_;
    holder[address(this)].excluded = stamp();
  }

  function getReport() external view returns (uint256 holderCount, bool stakingOn, uint256 totalTokensTracked, uint256 totalTokensStaked, uint256 totalRewardsPaid, uint256 requiredBalance, uint256 waitPeriodSeconds) {
    holderCount = holders;
    stakingOn = isStakingOn;
    totalTokensTracked = totalTracked;
    totalTokensStaked = totalBalance;
    totalRewardsPaid = totalDistributed;
    requiredBalance = minimumBalance;
    waitPeriodSeconds = waitingPeriod;
  }

  function getReportAccount(address key) public view returns (address account, uint256 index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    account = key;
    excluded = (holder[account].excluded > 0);
    index = excluded ? 0 : holder[account].index;
    tokens = excluded ? 0 : holder[account].tokens;
    stakedPercent = excluded ? 0 : holder[account].percent;
    stakedTokens = excluded ? 0 : balanceOf[account];
    rewardsEarned = getAccumulated(account);
    rewardsClaimed = withdrawnRewards[account];
    claimHours = excluded ? 0 : ageInHours(holder[account].claimed);
  }

  function getReportAccountAt(uint256 indexOf) public view returns (address account, uint256 index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    require(indexOf > 0 && indexOf <= holders, "Value invalid");

    return getReportAccount(holderAt[indexOf]);
  }

  function processClaims(uint256 gas) external onlyOwner {
    if (holders==0) return;

    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations < holders) {
      bool worthy = (address(this).balance > (1 ether / 10)); // ENOUGH FUNDS TO WARRANT PUSHING?
      // IF WORTHY 1 LOOP COST MAX ~65_000 GAS, UNWORTHY MAX ~8_500 GAS
      if (gasLeft < (worthy ? 65_000 : 8_500)) break; // EXIT IF NOT ENOUGH TO PROCESS THIS ITERATION TO AVOID OOG ERROR

      currentHolder = (currentHolder % holders) + 1;
      address account = holderAt[currentHolder];
      updatedWeightedBalance(account);
      if (worthy && pushFunds(payable(account))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    emit ClaimsProcessed(iterations, claims, currentHolder, gasUsed);
  }

  function setExcludedAddress(address account) external onlyOwner {
    require(holder[account].excluded==0, "Value unchanged");

    holder[account].excluded = stamp();
    putBalance(account, 0);
    holderRemove(account);
    emit ExcludedChanged(account, true);
  }

  // NEEDED TO REESTABLISH BALANCE WHEN INCLUDING SINCE EXCLUDING ZEROES IT OUT
  function setIncludedAddress(address account, uint256 balance) external onlyOwner {
    require(holder[account].excluded>0, "Value unchanged");

    holder[account].excluded = 0;

    if (balance > 0) {
      holderSet(account, balance);
      putWeighted(account);
    }
    emit ExcludedChanged(account, false);
  }

  function setMinimumBalance(uint256 newBalance) external onlyOwner {
    require(newBalance != minimumBalance, "Value unchanged");

    emit MinimumBalanceChanged(minimumBalance, newBalance);
    minimumBalance = newBalance;
  }

  function setWaitingPeriod(uint256 inSeconds) external onlyOwner {
    require(inSeconds != waitingPeriod, "Value unchanged");
    require(inSeconds >= 1 hours && inSeconds <= 1 days, "Value invalid");

    emit WaitingPeriodChanged(waitingPeriod, inSeconds);
    waitingPeriod = inSeconds;
  }

  function setStaking(bool setting) external onlyOwner {
    require(isStakingOn!=setting, "Value unchanged");
    isStakingOn = setting;
    emit StakingChanged(!setting, setting);
  }

  function trackBuy(address payable account, uint256 newBalance) external onlyOwner {
    if (holder[account].excluded > 0) return;

    if (holder[account].added==0) holder[account].added = stamp();
    holder[account].bought = stamp();
    setBalance(account, newBalance);
  }

  function trackSell(address payable account, uint256 newBalance) external onlyOwner {
    if (holder[account].excluded > 0) return;

    holder[account].sold = stamp();
    setBalance(account, newBalance);
  }

  function withdrawFunds(address payable account) public override onlyOwner { // EMITS EVENT
    require(getPending(account) > 0, "No funds");
    require(canClaim(holder[account].claimed), "Wait time active");

    updatedWeightedBalance(account);
    holder[account].claimed = stamp();
    super.withdrawFunds(account);
  }

  // PRIVATE

  function ageInHours(uint32 stamped) private view returns (uint32) {
    return stamped==0 ? 0 : (stamp() - stamped) / 1 hours;
  }

  function ageInWeeks(uint32 stamped) private view returns (uint32) {
    return ageInHours(stamped) / 24 / 7;
  }

  function canClaim(uint48 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= waitingPeriod;
  }

  function holderSet(address key, uint256 val) private {
    if (holder[key].index==0) {
      holders++;
      holderAt[holders] = key;
      holder[key].index = holders;
    }
    holder[key].tokens = val;
  }

  function holderRemove(address key) private {
    if (holder[key].index==0) return;

    // COPY LAST ROW INTO SLOT BEING DELETED
    holder[holderAt[holders]].index = holder[key].index;
    holderAt[holder[key].index] = holderAt[holders];

    delete holderAt[holders];
    holders--;
    holder[key].index = 0;
  }

  function setBalance(address payable account, uint256 newBalance) private {
    if (newBalance < minimumBalance) { // BELOW MIN DOES NOT QUALIFY
      totalTracked -= holder[account].tokens;
      putBalance(account, 0);
      holderRemove(account); // REMOVE FROM ARRAY TO THIN STORAGE
      return;
    }

    if (newBalance > holder[account].tokens) {
      totalTracked += newBalance.sub(holder[account].tokens);
    } else if(newBalance < holder[account].tokens) {
      totalTracked -= holder[account].tokens.sub(newBalance);
    }

    holderSet(account, newBalance);
    putWeighted(account);

    if (getPending(account) <= 0) return; // NOTHING PENDING WE ARE DONE HERE
    // PUSH FUNDS TO ACCOUNT W/EVENT AND UPDATE CLAIMED STAMP
    holder[account].claimed = stamp();
    super.withdrawFunds(account);
  }

  function stakePercent(address account) internal view returns (uint32) {
    if (!isStakingOn) return 100;
    uint32 stamped = holder[account].sold;
    if (stamped==0) stamped = holder[account].added;
    uint32 age = ageInWeeks(stamped);
    return (age > 4) ? 100 : 40 + 15 * age;
  }

  function stamp() private view returns (uint32) {
    return uint32(block.timestamp); // - 1231006505 seconds past BTC epoch
  }

  function pushFunds(address payable account) internal returns (bool) {
    if (!canClaim(holder[account].claimed) || getPending(account)==0) return false;

    super.withdrawFunds(account);

    holder[account].claimed = stamp();
    return true;
  }

  function putWeighted(address account) private {
    holder[account].percent = stakePercent(account);
    putBalance(account, weightedBalance(account));
  }

  function weightedBalance(address account) internal view returns (uint256) {
    uint256 balance = holder[account].tokens;
    if (!isStakingOn || balance==0 || holder[account].percent > 99) return balance;
    return balance.mul(holder[account].percent).div(100);
  }

  function updatedWeightedBalance(address account) internal {
    if (holder[account].percent==stakePercent(account)) return; // NO CHANGE
    putWeighted(account); // REWEIGHT TOKENS
  }
}

contract Odyssey is ERC20, Ownable {
  using SafeMath for uint256;
  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  OdysseyRewards public odysseyRewards;

  uint256 public constant FINAL_SUPPLY = 50_000_000_000 ether; // 50B FINAL SUPPLY / NO MINTING
  uint256 public constant MAX_WALLET = 5_000_000_000 ether; // MAX PER WALLET: 5_000_000_000 / 10%
  uint256 public constant MAX_SELL = 500_000_000 ether; // MAX PER SELL: 500_000_000 / 1%

  bool public isOpenToPublic = false;
  address payable public projectWallet;
  address payable public liquidityAddress;
  uint256 public accumulatedRewards = 0;
  uint256 public accumulatedProject = 0;
  uint256 public accumulatedLiquidity = 0;
  uint16[4] public feeLevel = [1,1,1,1]; // STATE CAPACITOR
  uint16 public feeToBuy = 2;
  uint16 public feeToSell = 12;
  uint16 public feeLiquidity = 5;
  uint16 public feeProject = 3;
  uint16 public feeRewards = 4;
  uint256 public swapThreshold = 16_000_000 ether; // CONTRACT SWAPS TO BSD: 16_000_000
  uint256 public gasLimit = 300_000; // GAS FOR REWARDS PROCESSING

  // MAPPINGS
  mapping (address => bool) public autoMarketMakers; // Any transfer to these addresses are likely sells
  mapping (address => bool) public isFeeless; // exclude from all fees and maxes
  mapping (address => bool) public isPresale; // can trade in PreSale

  // EVENTS

  event FeesChanged(uint256 feeToBuy, uint256 feeToSell, uint256 feeRewards, uint256 feeProject, uint256 feeLiquidity, uint256 swapAt);
  event FundsReceived(address indexed from, uint amount);
  event FundsSentToLiquidity(uint256 tokens, uint256 value);
  event FundsSentToProject(uint256 tokens, uint256 value);
  event FundsSentToRewards(uint256 tokens, uint256 value);
  event GasLimitChanged(uint256 from, uint256 to);
  event IsFeelessChanged(address indexed account, bool excluded);
  event LiquidityAddressChanged(address indexed from, address indexed to);
  event ProjectWalletChanged(address indexed from, address indexed to);
  event RewardsTrackerChanged(address indexed from, address indexed to);
  event SetAutomatedMarketMakerPair(address indexed pair, bool active);
  event MarketCapCalculated(uint256 price, uint256 marketCap, uint256 tokens, uint256 value);

  // INTERNAL VARS
  bool private swapping = false;

  // INITIALIZE CONTRACT
  constructor() ERC20("Odyssey", "$ODSY") {
    // SETUP PANCAKESWAP
    address ROUTER_PCSV2_MAINNET = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    IUniswapV2Router02 router = IUniswapV2Router02(ROUTER_PCSV2_MAINNET);
    address pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());
    uniswapV2Router = router;
    uniswapV2Pair = pair;
    autoMarketMakers[pair] = true;

    projectWallet = payable(owner());
    liquidityAddress = payable(owner());
    isPresale[owner()] = true;
    isFeeless[address(this)] = true;
    isFeeless[projectWallet] = true;

    odysseyRewards = new OdysseyRewards("OdysseyRewards", "ODSYRV1");
    setDefaultRewardsExclusions();
    setFeesByLevel(1);

    _mint(address(owner()), FINAL_SUPPLY);
  }

  // To receive ETH when swapping
  receive() external payable {
    emit FundsReceived(msg.sender, msg.value);
  }

  function balanceOfLiquidity() external view returns(uint256) {
    return IUniswapV2Pair(uniswapV2Pair).balanceOf(address(this));
  }

  function openToPublic() external onlyOwner { // NO GOING BACK
    require(!isOpenToPublic, "Value unchanged");

    if (address(this).balance > 0 && address(this).balance > 0) {
      // INITIAL LIQUIDITY GOES TO OWNER TO LOCK
      addLiquidity(balanceOf(address(this)), address(this).balance);
    }

    isOpenToPublic = true;

    liquidityAddress = payable(address(this)); // GENERATED LIQUIDITY STAYS IN CONTRACT
    emit LiquidityAddressChanged(owner(), address(this));
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
    require(pair != uniswapV2Pair, "Value invalid");
    require(autoMarketMakers[pair] != value, "Value unchanged");
    autoMarketMakers[pair] = value;
    odysseyRewards.setExcludedAddress(pair);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function setFeeless(address account, bool setting) external onlyOwner {
    require(isFeeless[account]!=setting, "Value unchanged");

    isFeeless[account] = setting;
    emit IsFeelessChanged(account, setting);
  }

  function setGasLimit(uint256 gas) external onlyOwner {
    require(gas >= 250_000 && gas <= 750_000, "Value invalid");
    require(gas != gasLimit, "Value unchanged");
    emit GasLimitChanged(gasLimit, gas);
    gasLimit = gas;
  }

  function setPresale(address account, bool setting) external onlyOwner {
    isPresale[account] = setting;
  }

  function setProjectWallet(address wallet) external {
    require(msg.sender==projectWallet, "Value invalid"); // ONLY PROJECTWALLET CAN CHANGE ITSELF
    require(wallet!=projectWallet, "Value unchanged");

    address oldWallet = projectWallet;
    projectWallet = payable(wallet);
    isFeeless[oldWallet] = false;
    isFeeless[wallet] = true;
    emit ProjectWalletChanged(oldWallet, projectWallet);
  }

  function setRewardsTracker(address newAddress) external onlyOwner {
    require(newAddress != address(odysseyRewards), "Value unchanged");

    OdysseyRewards newTracker = OdysseyRewards(payable(newAddress));

    require(newTracker.owner() == address(this), "Token must own tracker");

    emit RewardsTrackerChanged(address(odysseyRewards), newAddress);

    odysseyRewards.transferOwnership(owner());
    odysseyRewards = newTracker;
    setDefaultRewardsExclusions();
  }

  // *************************************
  // FUNCTIONS DELEGATED TO RewardsTracker

  function getRewardsReport() external view returns (uint256 holderCount, bool stakingOn, uint256 totalTokensTracked, uint256 totalTokensStaked, uint256 totalRewardsPaid, uint256 requiredBalance, uint256 waitPeriodSeconds) {
    return odysseyRewards.getReport();
  }

  function getRewardsReportAccount(address key) external view returns (address account, uint256 index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    return odysseyRewards.getReportAccount(key);
  }

  function getRewardsReportAccountAt(uint256 indexOf) external view returns (address account, uint256 index, bool excluded, uint256 tokens, uint256 stakedPercent, uint256 stakedTokens, uint256 rewardsEarned, uint256 rewardsClaimed, uint256 claimHours) {
    return odysseyRewards.getReportAccountAt(indexOf);
  }

  function processRewardsClaims() external onlyOwner {
    try odysseyRewards.processClaims(gasLimit) {} catch {}
  }

  function setRewardsExcludedAddress(address account, bool exclude) external onlyOwner {
    if (exclude) {
      odysseyRewards.setExcludedAddress(account);
    } else {
      odysseyRewards.setIncludedAddress(account, balanceOf(account));
    }
  }

  function setRewardsMinimumBalance(uint256 amount) external onlyOwner {
    require(amount >= 1_000_000 && amount <= 15_000_000, "Value invalid");
    require(odysseyRewards.minimumBalance() > (amount * 1 ether), "Value cannot increase");

    odysseyRewards.setMinimumBalance(amount * 1 ether);
  }

  function setRewardsStaking(bool setting) external onlyOwner {
    odysseyRewards.setStaking(setting);
  }

  function setRewardsWaitingPeriod(uint256 waitSeconds) external onlyOwner {
    odysseyRewards.setWaitingPeriod(waitSeconds);
  }

  function withdrawRewards() external {
    odysseyRewards.withdrawFunds(payable(msg.sender));
  }

  function _transfer(address from, address to, uint256 amount) internal override {
    require(from != address(0) && to != address(0), "Value invalid");
    require(amount > 0, "Value invalid");

    require(to==address(this) || autoMarketMakers[to] || balanceOf(to).add(amount) <= MAX_WALLET, "Wallet over limit");

    if (!isOpenToPublic && isPresale[from]) { // PRE-SALE WALLET - NO FEES, JUST TRANSFER AND UPDATE TRACKER BALANCES
      transferAndUpdateRewardsTracker(from, to, amount);
      return;
    }

    require(isOpenToPublic, "Trading closed");

    if (!autoMarketMakers[to] && !autoMarketMakers[from]) { // NOT A SALE, NO FEE TRANSFER
      transferAndUpdateRewardsTracker(from, to, amount);
      try odysseyRewards.processClaims(gasLimit) {} catch {}
      return; // NO TAXES
    }

    if (!swapping) {
      bool feePayer = !isFeeless[from] && !isFeeless[to];
      if (feePayer) { // RENDER UNTO CAESAR THE THINGS THAT ARE CAESAR"S
        uint256 taxTotal = 0;
        if (autoMarketMakers[to] && from!=address(uniswapV2Router)) { // SELL
          require(amount <= MAX_SELL, "Sell over limit");
          taxTotal = amount.mul(feeToSell).div(100);
          if (taxTotal > 0) {
            uint256 taxLiquidity = taxTotal.mul(feeLiquidity).div(feeToSell);
            uint256 taxProject = taxTotal.mul(feeProject).div(feeToSell);
            uint256 taxRewards = taxTotal.sub(taxProject.add(taxLiquidity));
            accumulatedLiquidity += taxLiquidity;
            accumulatedProject += taxProject;
            accumulatedRewards += taxRewards;
          }
        } else { // BUY
          taxTotal = amount.mul(feeToBuy).div(100);
          accumulatedProject += taxTotal;
        }
        if (taxTotal > 0) {
          super._transfer(from, address(this), taxTotal);
          amount -= taxTotal;
        }
      }

      if (!autoMarketMakers[from] && from!=liquidityAddress && to!=liquidityAddress) {
        swapping = true;
        processAccumulatedTokens();
        swapping = false;
      }
    }

    transferAndUpdateRewardsTracker(from, to, amount);

    if (!swapping) {
      try odysseyRewards.processClaims(gasLimit) {} catch {}
    }
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, liquidityAddress, block.timestamp);
  }

  function changeMarketCap(uint256 swappedETH, uint256 tokens) private {
    uint256 marketCap = swappedETH.mul(FINAL_SUPPLY).div(tokens).div(1 ether);
    uint256 price = marketCap.mul(1 ether).div(FINAL_SUPPLY.div(1 ether));
    emit MarketCapCalculated(price, marketCap, tokens, swappedETH); // TESTING

    uint16 level = // MC IN BNB NOT USD
      (marketCap <   8_000) ? 1 :
      (marketCap <  16_000) ? 2 :
      (marketCap <  32_000) ? 3 :
      (marketCap <  64_000) ? 4 :
      (marketCap < 128_000) ? 5 :
      (marketCap < 256_000) ? 6 :
      (marketCap < 512_000) ? 7 : 8;

    if (feesChanged(level)) {
      setFeesByLevel(level);

      // ONCE LIQUIDITY FEE GOES TO ZERO WE MAY NEVER COLLECT AGAIN,
      if (feeLiquidity==0 && accumulatedLiquidity > 0) {
        accumulatedRewards += accumulatedLiquidity;
        accumulatedLiquidity = 0;
      }
      emit FeesChanged(feeToBuy, feeToSell, feeRewards, feeProject, feeLiquidity, swapThreshold);
    }
  }

  function feesChanged(uint16 level) private returns (bool) {
    // STORE PAST 3 READINGS; 4TH IS CURRENT STATE
    uint i;
    bool flag = true;
    for (i=0;i<3;i++) feeLevel[i] = (i<2) ? feeLevel[i+1] : level; // SHIFT & STORE
    // IF 1ST 3 EQ AND THE 4 IS NOT LEVEL HAS CHANGED AND STABLIZED
    for (i=0;i<3;i++) flag = flag && (i<2 ? feeLevel[i]==feeLevel[i+1] : feeLevel[i]!=feeLevel[i+1]);
    if (flag) feeLevel[3] = level; // 4TH SLOT HOLDS CURRENT LEVEL
    return flag;
  }

  function processAccumulatedTokens() private {
    if (balanceOf(address(this)) >= swapThreshold) swapAndAddLiquidity(swapThreshold);
    if (balanceOf(address(this)) >= swapThreshold) swapAndSendToRewardsTracker(swapThreshold);
    if (balanceOf(address(this)) >= swapThreshold) swapAndSendToProject(swapThreshold);
  }

  function setDefaultRewardsExclusions() private {
    odysseyRewards.setExcludedAddress(uniswapV2Pair);
    odysseyRewards.setExcludedAddress(address(this));
    odysseyRewards.setExcludedAddress(address(uniswapV2Router));
    odysseyRewards.setExcludedAddress(projectWallet);
  }

  function setFeesByLevel(uint16 level) private {
    swapThreshold = uint256((17-level)) * 1_000_000 ether;
    feeLiquidity = (level<5) ? (5-level) : 0;
    feeProject = (level<5) ? (5-level) : 1;
    feeRewards = (13-level) - feeLiquidity - feeProject;
    feeToSell = feeRewards + feeProject + feeLiquidity;
  }

  function swapAndAddLiquidity(uint256 tokens) private {
    if (accumulatedLiquidity < tokens) return; // NOT YET

    accumulatedLiquidity -= tokens;
    uint256 swapHalf = tokens.div(2);
    uint256 liquidTokens = tokens.sub(swapHalf);
    uint256 liquidETH = swapTokensForETH(swapHalf);
    addLiquidity(liquidTokens, liquidETH);
    emit FundsSentToLiquidity(liquidTokens, liquidETH);
  }

  function swapAndSendToRewardsTracker(uint256 tokens) private {
    if (accumulatedRewards < tokens) return; // NOT YET

    accumulatedRewards -= tokens;
    uint256 swappedETH = swapTokensForETH(tokens);
    if (swappedETH > 0) {
      (bool success,) = address(odysseyRewards).call{value: swappedETH}("");
      if (success) {
        emit FundsSentToRewards(tokens, swappedETH);
        changeMarketCap(swappedETH, tokens);
      }
    }
  }

  function swapAndSendToProject(uint256 tokens) private {
    if (accumulatedProject < tokens) return; // NOT YET

    accumulatedProject -= tokens;
    uint256 swappedETH = swapTokensForETH(tokens);
    if (swappedETH > 0) {
      (bool success,) = address(projectWallet).call{value: swappedETH}("");
      if (success) emit FundsSentToProject(tokens, swappedETH);
    }
  }

  function swapTokensForETH(uint256 tokens) private returns(uint256) {
    address[] memory pair = new address[](2);
    pair[0] = address(this);
    pair[1] = uniswapV2Router.WETH();
    _approve(address(this), address(uniswapV2Router), tokens);
    uint256 currentETH = address(this).balance;
    uniswapV2Router.swapExactTokensForETH(tokens, 0, pair, address(this), block.timestamp);
    return address(this).balance.sub(currentETH);
  }

  function transferAndUpdateRewardsTracker(address from, address to, uint256 amount) private {
    super._transfer(from, to, amount);
    try odysseyRewards.trackSell(payable(from), balanceOf(from)) {} catch {}
    try odysseyRewards.trackBuy(payable(to), balanceOf(to)) {} catch {}
  }
}

contract OdysseyProject is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;

  struct Holder {
    uint256 index;
    uint256 share;
  }

  uint256 public holders = 0;
  uint256 public currentHolder = 0;
  mapping (uint256 => address) public holderAt;
  mapping (address => Holder) public holder;

  Odyssey public odyssey;

  uint256 public dividends = 10;
  uint256 public dividendsInBNB = 0;
  uint256 public funds = 0;
  address public ceo1 = address(0);
  address public ceo2 = address(0);
  address public cfo1 = address(0);
  address public cfo2 = address(0);

  uint256 public minimumBalance = 10_000_000 ether; // 10M TOKENS REQ FOR DIVIDENDS

  struct VoteOfficer {
    address from;
    address to;
    bool voted;
  }

  struct VoteContract {
    address to;
    bool voted;
  }

  struct VoteFunds {
    address to;
    uint256 amount;
    bool voted;
  }

  mapping (address => VoteContract) public voteContract;
  mapping (address => VoteOfficer) public voteOfficer;
  mapping (address => VoteFunds) public voteFunds;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);
  event ContractChanged(address from, address to);
  event ContractVote(address officer, address to);
  event ContractVoteReset();
  event FundsApproved(address to, uint256 amount);
  event FundsRequest(address officer, address to, uint256 amount);
  event FundsRequestReset();
  event OfficerChanged(address from, address to);
  event OfficerVote(address officer, address from, address to);
  event OfficerVoteReset();
  event MinimumBalanceChanged(uint256 from, uint256 to);

  constructor() RewardsTracker() { }

  modifier onlyOfficer() {
    require(msg.sender==ceo1 || msg.sender==ceo2 || msg.sender==cfo1 || msg.sender==cfo2, "Invalid Officer");
    _;
  }

  function getReport() public view returns (uint256 holderCount, uint256 totalDollars, uint256 totalDividends) {
    holderCount = holders;
    totalDollars = totalBalance;
    totalDividends = totalDistributed;
  }

  function getReportAccount(address key) public view returns (address account, uint256 index, uint256 shares, uint256 dividendsEarned, uint256 dividendsClaimed) {
    account = key;
    index = holder[account].index;
    shares = balanceOf[account];
    dividendsEarned = getAccumulated(account);
    dividendsClaimed = withdrawnRewards[account];
  }

  function getReportAccountAt(uint256 indexOf) public view returns (address account, uint256 index, uint256 shares, uint256 dividendsEarned, uint256 dividendsClaimed) {
    require(indexOf > 0 && indexOf <= holders, "Value invalid");

    return getReportAccount(holderAt[indexOf]);
  }

  function processClaims(uint256 gas) external {
    if (holders==0) return;

    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations <= holders) {
      currentHolder = (currentHolder % holders) + 1;
      if (pushFunds(payable(holderAt[currentHolder]))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    emit ClaimsProcessed(iterations, claims, currentHolder, gasUsed);
  }

  function replaceContract(address to) external onlyOfficer {
    voteContract[msg.sender].to = to;
    voteContract[msg.sender].voted = true;
    emit ContractVote(msg.sender, to);

    bool unanimous = (voteContract[ceo1].to==to && voteContract[ceo2].to==to && voteContract[cfo1].to==to && voteContract[cfo2].to==to);

    if (unanimous) {
      odyssey.setProjectWallet(to);
      emit ContractChanged(address(this), to);
    }

    bool disagree = (voteContract[ceo1].voted && voteContract[ceo1].to!=to) ||
                    (voteContract[ceo2].voted && voteContract[ceo2].to!=to) ||
                    (voteContract[cfo1].voted && voteContract[cfo1].to!=to) ||
                    (voteContract[cfo2].voted && voteContract[cfo2].to!=to);

    if (unanimous || disagree) {
      delete voteContract[ceo1];
      delete voteContract[ceo2];
      delete voteContract[cfo1];
      delete voteContract[cfo2];
      if (disagree) emit ContractVoteReset();
    }
  }

  function replaceOfficer(address from, address to) external onlyOfficer {
    require(from!=address(0) && to!=address(0), "Value invalid");
    require(from!=msg.sender && to!=msg.sender, "Value invalid");
    require(from==ceo1 || from==ceo2 || from==cfo1 || from==cfo2, "Invalid Officer");
    require(to!=ceo1 || to!=ceo2 || to!=cfo1 || to!=cfo2, "Existing Officer");

    bool replacingVoter =
      voteOfficer[ceo1].from==msg.sender ||
      voteOfficer[ceo2].from==msg.sender ||
      voteOfficer[cfo1].from==msg.sender ||
      voteOfficer[cfo2].from==msg.sender;

    require(!replacingVoter, "Outgoing Officer cannot vote.");

    voteOfficer[msg.sender].from = from;
    voteOfficer[msg.sender].to = to;
    voteOfficer[msg.sender].voted = true;
    emit OfficerVote(msg.sender, from, to);

    bool unanimous =
      (from==ceo1 || voteOfficer[ceo1].from==from && voteOfficer[ceo1].to==to) &&
      (from==ceo2 || voteOfficer[ceo2].from==from && voteOfficer[ceo2].to==to) &&
      (from==cfo1 || voteOfficer[cfo1].from==from && voteOfficer[cfo1].to==to) &&
      (from==cfo2 || voteOfficer[cfo2].from==from && voteOfficer[cfo2].to==to);

    if (unanimous) {
      if (from==ceo1) ceo1 = to;
      if (from==ceo2) ceo2 = to;
      if (from==cfo1) cfo1 = to;
      if (from==cfo2) cfo2 = to;
      emit OfficerChanged(from, to);
    }

    bool disagree =
      (voteOfficer[ceo1].voted && (voteOfficer[ceo1].from!=from || voteOfficer[ceo1].to!=to)) ||
      (voteOfficer[ceo2].voted && (voteOfficer[ceo2].from!=from || voteOfficer[ceo2].to!=to)) ||
      (voteOfficer[cfo1].voted && (voteOfficer[cfo1].from!=from || voteOfficer[cfo1].to!=to)) ||
      (voteOfficer[cfo2].voted && (voteOfficer[cfo2].from!=from || voteOfficer[cfo2].to!=to));

    if (unanimous || disagree) {
      delete voteOfficer[ceo1];
      delete voteOfficer[ceo2];
      delete voteOfficer[cfo1];
      delete voteOfficer[cfo2];
      if (disagree) emit OfficerVoteReset();
    }
  }

  function requestFunds(address to, uint256 amount) external onlyOfficer {
    require(funds > amount, "Overdraft");

    voteFunds[msg.sender].to = to;
    voteFunds[msg.sender].amount = amount;
    voteFunds[msg.sender].voted = true;
    emit FundsRequest(msg.sender, to, amount);

    // IF CEO IS REQUESTING, CHECK IF EITHER CFO APPROVED AND VISE VERSA
    bool approved = (msg.sender==ceo1 || msg.sender==ceo2) ?
                    (voteFunds[cfo1].to==to && voteFunds[cfo1].amount==amount) || (voteFunds[cfo2].to==to && voteFunds[cfo2].amount==amount) :
                    (voteFunds[ceo1].to==to && voteFunds[ceo1].amount==amount) || (voteFunds[ceo2].to==to && voteFunds[ceo2].amount==amount);

    if (approved) {
      funds -= amount;
      (bool success,) = payable(to).call{ value: amount, gas: 3000 }("");
      if (success) {
        emit FundsApproved(to, amount);
      } else {
        funds += amount;
      }
    }

    bool disagree = (voteFunds[ceo1].voted && (voteFunds[ceo1].to!=to || voteFunds[ceo1].amount!=amount)) ||
                    (voteFunds[ceo2].voted && (voteFunds[ceo2].to!=to || voteFunds[ceo2].amount!=amount)) ||
                    (voteFunds[cfo1].voted && (voteFunds[cfo1].to!=to || voteFunds[cfo1].amount!=amount)) ||
                    (voteFunds[cfo2].voted && (voteFunds[cfo2].to!=to || voteFunds[cfo2].amount!=amount));

    if (approved || disagree) {
      delete voteFunds[ceo1];
      delete voteFunds[ceo2];
      delete voteFunds[cfo1];
      delete voteFunds[cfo2];
      if (disagree) emit FundsRequestReset();
    }
  }

  function setHolders(address[] memory wallets, uint256[] memory dollars) external onlyOwner {
    require(totalBalance==0, "Shares already set.");
    require(wallets.length < 100, "100 wallets max");

    for (uint256 idx=0;idx<wallets.length;idx++) {
      setHolder(wallets[idx], dollars[idx]);
    }

    dividendsInBNB = (totalBalance * 1 ether).div(333); // FOR EACH 1K DOLLARS RETURN 3 BNB TO INVESTORS - ADJUST TO CURRENT BNB PRICE AT LAUNCH
  }

  function setOfficers(address[] memory wallets) external onlyOwner {
    require(ceo1==address(0), "Officers already set");
    require(wallets.length==4, "4 Officers required");
    for (uint256 idx=0;idx<4;idx++) {
      require(wallets[idx]!=address(0), "Value invalid"); // NON-ZERO
      for (uint256 jdx=0;jdx<4;jdx++) {
        if (idx!=jdx) require(wallets[idx]!=wallets[jdx], "Value invalid"); // UNIQUE
      }
    }

    ceo1 = wallets[0];
    ceo2 = wallets[1];
    cfo1 = wallets[2];
    cfo2 = wallets[3];
  }

  function setMinimumBalance(uint256 amount) external onlyOfficer {
    require(amount >= 1_000_000 && amount <= 10_000_000, "Value invalid");
    uint256 balance = (amount * 1 ether);
    require(balance != minimumBalance, "Value unchanged");
    require(minimumBalance > balance, "Value cannot increase");

    emit MinimumBalanceChanged(minimumBalance, balance);
    minimumBalance = balance;
  }

  function setToken(address token) external onlyOwner {
    require(address(odyssey)==address(0), "Token already set");

    odyssey = Odyssey(payable(token));
  }

  function withdrawFunds(address payable account) public override {
    require(getPending(account) > 0, "No funds");

    verifyMinimumBalance(account);
    super.withdrawFunds(account);
  }

  // PRIVATE

  function distributeFunds(uint256 amount) internal override {
    if (totalDistributed > dividendsInBNB) { // PAID IN FULL, NO MORE DISTRIBUTIONS
      funds += amount;
      return;
    }
    uint256 share = amount.mul(dividends).div(100);
    funds += amount.sub(share);
    super.distributeFunds(share);
  }

  function holderSet(address key, uint256 share) internal {
    if (holder[key].index==0) {
      holders++;
      holderAt[holders] = key;
      holder[key].index = holders;
    }
    holder[key].share = share;
  }

  function setHolder(address account, uint256 dollars) internal {
    putBalance(account, dollars);
    holderSet(account, dollars);
  }

  function pushFunds(address payable account) internal returns (bool) {
    verifyMinimumBalance(account);

    if (getPending(account)==0) return false;

    super.withdrawFunds(account);

    return true;
  }

  function verifyMinimumBalance(address account) internal {
    if (minimumBalance==0) return;

    if (balanceOf[account] > 0 && odyssey.balanceOf(account) < minimumBalance) {
      putBalance(account, 0);
    } else if (balanceOf[account] == 0 && odyssey.balanceOf(account) >= minimumBalance) {
      putBalance(account, holder[account].share);
    }
  }
}
