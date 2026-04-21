import numpy as np

def simulate_covered_call_vault(
    initial_eth_price=2000,
    weeks=52,
    vol=0.80,
    strike_pct=1.10,     # Strike = 10% above current price
    risk_free=0.05
):
    """
    Simulate a Ribbon-style covered call vault over 1 year
    """
    eth_price = initial_eth_price
    total_eth = 1.0
    total_premium_collected = 0
    times_called_away = 0
    
    for week in range(weeks):
        strike = eth_price * strike_pct
        T = 7/365  # 1 week
        
        # Price the call we're selling
        greeks = option_greeks(eth_price, strike, T, risk_free, vol, 'call')
        premium = greeks['price']
        total_premium_collected += premium
        
        # Simulate next week's ETH price (log-normal)
        weekly_return = np.random.normal(0, vol * np.sqrt(T))
        new_eth_price = eth_price * np.exp(weekly_return)
        
        # Did option get exercised?
        if new_eth_price > strike:
            # ETH "called away" at strike price
            times_called_away += 1
            eth_price = strike  # We sold at strike, miss extra upside
        else:
            eth_price = new_eth_price
    
    final_value = eth_price * total_eth
    premium_yield = total_premium_collected / initial_eth_price
    
    print(f"Initial ETH price: ${initial_eth_price}")
    print(f"Final ETH price:   ${eth_price:.2f}")
    print(f"Premiums collected: ${total_premium_collected:.2f} ({premium_yield:.1%} yield)")
    print(f"Called away: {times_called_away}/{weeks} weeks")
    print(f"Final portfolio: ${final_value + total_premium_collected:.2f}")
    print(f"vs Buy & Hold:   ${initial_eth_price * (eth_price/initial_eth_price):.2f}")

# Run 1000 simulations, compare outcomes
results = [simulate_covered_call_vault() for _ in range(1000)]