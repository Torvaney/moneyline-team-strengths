data {
  int<lower=1> n_games;
  int<lower=2> n_teams;
  int<lower=1> n_seasons;

  int<lower=1, upper=n_teams> home_team[n_games];
  int<lower=1, upper=n_teams> away_team[n_games];
  int<lower=1, upper=n_seasons> season[n_games];
  real home_logit[n_games];
  real away_logit[n_games];
}

parameters {
  real<lower=0> sigma;
  real theta_home;
  real theta_away;
  vector[n_teams-1] team_strength_init;
  matrix[n_teams-1, n_seasons-1] team_strength_changes;
}

transformed parameters {
  matrix[n_teams, n_seasons] team_strength;
  vector[n_games] strength_diff;

  // Enforce sum-to-zero constraint for initial ratings
  for (t in 1:(n_teams-1)) {
    team_strength[t, 1] = team_strength_init[t];
  }
  team_strength[n_teams, 1] = -sum(team_strength_init);

  // Calculate subsequent team strengths
  for (s in 1:(n_seasons-1)) {
    for (t in 1:(n_teams-1)) {
      team_strength[t, s+1] = (
        team_strength[t, 1] +  // Initial strength
        sum(team_strength_changes[t, 1:s])  // Total changes
      );
    }
    team_strength[n_teams, s+1] = -sum(team_strength[1:(n_teams-1), s+1]);
  }

  for (g in 1:n_games) {
    strength_diff[g] = (
      team_strength[home_team[g], season[g]] -
      team_strength[away_team[g], season[g]]
    );
  }
}

model {
  // Uninformative priors
  sigma ~ normal(0, 1);
  theta_home ~ normal(0, 1);
  theta_away ~ normal(0, 1);
  team_strength_init ~ normal(0, 1);
  for (s in 1:(n_seasons-1))
    team_strength_changes[:, s] ~ normal(0, 0.1);

  // Sampling
  home_logit ~ normal(theta_home + strength_diff, sigma);
  away_logit ~ normal(theta_away - strength_diff, sigma);
}
