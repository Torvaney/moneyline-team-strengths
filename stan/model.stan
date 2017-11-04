data {
  int<lower=1> n_games;
  int<lower=2> n_teams;

  int<lower=1, upper=n_teams> home_team[n_games];
  int<lower=1, upper=n_teams> away_team[n_games];
  real home_logit[n_games];
  real away_logit[n_games];
}

parameters {
  real<lower=0> sigma;
  real theta_home;
  real theta_away;  // Ignore the draw for now...
  vector[n_teams-1] team_strength_raw;
}

transformed parameters {
  real team_strength[n_teams];
  vector[n_games] strength_diff;

  // Enforce sum-to-zero constraint
  for (t in 1:(n_teams-1)) {
    team_strength[t] = team_strength_raw[t];
  }
  team_strength[n_teams] = -sum(team_strength_raw);

  for (g in 1:n_games) {
    strength_diff[g] = team_strength[home_team[g]] - team_strength[away_team[g]];
  }
}

model {
  // Uninformative priors
  sigma ~ normal(0, 1);
  theta_home ~ normal(0, 10);
  theta_away ~ normal(0, 10);
  team_strength ~ normal(0, 1);

  // Sampling
  home_logit ~ normal(theta_home + strength_diff, sigma);
  away_logit ~ normal(theta_away - strength_diff, sigma);
}
