import argparse
import os

import numpy as np
import pandas as pd
import pystan


def logit(p):
    return np.log(p / (1.0 - p))


def logistic(a):
    return 1.0 / (1 + np.exp(-a))


def normalise_odds(home_win, draw, away_win):
    """
    Normalise odds to probabilities linearly.

    This has been shown to be biased, but it is quicker and easier than a
    logistic regression.
    """
    probs = [1. / odds for odds in (home_win, draw, away_win)]
    juiced_probability = sum(probs)
    return [p / juiced_probability for p in probs]


def get_map(items):
    return {name: id_ for id_, name in enumerate(set(items), start=1)}


def get_team_map(games):
    """ Get a mapping of teamname to makeshift id from a dataframe of games. """
    team_names = set(games['home_team']) | set(games['away_team'])
    return get_map(team_names)


def prepare_games(games):
    """
    Prepare a dataframe of games for fitting the Stan model. This simply means
    adding a few calculated columns to the dataframe:
     * Implied probabilities (normalised linearly by `normalise_odds`)
     * The logit of those probabilities (map from [0, 1] to +/- Inf)
    """
    games = games.copy()

    odds_columns = ['home_win', 'draw', 'away_win']
    probabilities = games[odds_columns].apply(
        lambda row: normalise_odds(**row), axis=1
    )
    games = games.merge(
        probabilities,
        left_index=True,
        right_index=True,
        suffixes=['', '_prob']
    )

    for col in odds_columns:
        games[col + '_logit'] = logit(games[col + '_prob'])

    return games


def run_stan_model(games):
    """
    Compiles and fits a model via MLE in Stan, returning the fitted parameters.
    """

    # Create the model
    model = pystan.StanModel(os.path.join(
        os.path.dirname(__file__),
        'stan/model.stan'
    ))

    # Stan only takes numeric values. Create team: id mapping to pass factors
    # between python and Stan
    team_map = get_team_map(games)
    season_map = get_map(games['season'])

    # Put the data into Stan format
    stan_data = {
        'n_games': len(games),
        'n_teams': len(team_map),
        'n_seasons': len(season_map),
        'home_team': games['home_team'].replace(team_map),
        'away_team': games['away_team'].replace(team_map),
        'season': games['season'].replace(season_map),
        'home_logit': games['home_win_logit'],
        'away_logit': games['away_win_logit']
    }

    # Fit and output estimates
    fit = model.sampling(stan_data, iter=4000)

    return fit


def parse_stan_fit(fit, games, alpha=0.05):
    # Aggregate sampling for speed
    lower_strengths = np.percentile(fit['team_strength'], alpha*100, axis=0)
    median_strengths = np.median(fit['team_strength'], axis=0)
    upper_strengths = np.percentile(fit['team_strength'], (1-alpha)*100, axis=0)

    # Parse model output into a nice dataframe
    team_map = get_team_map(games)
    season_map = get_map(games['season'])
    team_strength_records = []
    for team, ti in team_map.items():
        for season, si in season_map.items():
            team_strength_records.append({
                'team': team,
                'season': season,
                'lower': lower_strengths[ti-1, si-1],
                'strength': median_strengths[ti-1, si-1],
                'upper': upper_strengths[ti-1, si-1]
            })
    team_strength = pd.DataFrame(team_strength_records)
    return team_strength


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('oddsfile', type=str, help='Path to csv of odds data.')
    parser.add_argument('outfile', type=str, help='Where to save output csv of '
                        'team strength estimates')
    args = parser.parse_args()

    # Load and wrangle the data
    games = pd.read_csv(args.oddsfile)
    games = prepare_games(games)

    # Fit the model
    fit = run_stan_model(games)

    team_strength = parse_stan_fit(fit, games)
    team_strength.to_csv(args.outfile, index=False, encoding='utf-8')
