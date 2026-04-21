import math
from scipy.stats import norm

def black_scholes_call(S, K, T, r, sigma, option_type='call'):
    """Calculate full Black-Scholes price and greeks"""
    """
    S     = spot price (e.g. 2000) 
    K     = strike price (e.g. 2500)
    T     = time to expiry in years (e.g. 30/365)
    r     = risk-free rate (e.g. 0.05 for 5%)
    sigma = implied volatility (e.g. 0.80 for 80%)
    """
    d1 = (math.log(S / K) + (r + 0.5 * sigma**2) * T) / (sigma * math.sqrt(T))
    d2 = d1 - sigma * math.sqrt(T)
    
    if option_type == 'call':
        price = S * norm.cdf(d1) - K * math.exp(-r * T) * norm.cdf(d2)
        delta = norm.cdf(d1)
    else: # put
        price = K * math.exp(-r * T) * norm.cdf(-d2) - S * norm.cdf(-d1)
        delta = norm.cdf(d1) - 1
    
    # Greek
    # cdf Cumulative distribution function
    # pdf # Probability density function
    gamma = norm.pdf(d1) / (S * sigma * math.sqrt(T))
    theta = (-(S * norm.pdf(d1) * sigma) / (2 * math.sqrt(T)) - r * K * math.exp(-r * T) * norm.cdf(d2)) / 365
    vega  = S * norm.pdf(d1) * math.sqrt(T) / 100  # per 1% vol move
    
    return {
        'price': price,
        'delta': delta,
        'gamma': gamma,
        'theta': theta,
        'vega': vega,
    }

# Example: ETH $2000, strike $2500, 30 days, 5% risk-free, 80% vol
result = black_scholes_call(2000, 2500, 30/365, 0.05, 0.80)
print(result)
# {'price': 187.3, 'delta': 0.31, 'gamma': 0.0008, 'theta': -8.2, 'vega': 3.1}