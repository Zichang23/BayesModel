## Bayesian Modeling for Unemployment Trend Overtime in US

### 1. Introduction


### 2.  Data Exploration and Visualization

#### 2.1 

#### 2.2 

#### 2.3

### 3. Bayesian Modeling

#### 3.1 Model Specification

$$Y_{it}|\theta_{it} \backsim Poisson(E_{it}\theta_{it})$$

$$log(\theta_{it}) = \beta_0 + \beta_1 X_{GDP} + \beta_2 X_{consumption} + \beta_3 X_{jobs} + v_i + u_i + \gamma_t + \phi_t + \delta_{it}$$

$$\beta_0, \cdots, \beta_3 \backsim N(0, 10000)$$

$$u_i \backsim CAR$$

$$\gamma_t \backsim \text{Random Work Model}$$

$$\nu_i \mathop\backsim \limits^{iid} N(0, \sigma^2_{\nu})$$

$$\phi_t \mathop\backsim \limits^{iid} N(0, \sigma^2_{\phi})$$

$$\delta_{it} \mathop\backsim \limits^{iid} N(0, \sigma^2_{\delta})$$
