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


def get_team_map(games):
    """ Get a mapping of teamname to makeshift id from a dataframe of games. """
    team_names = set(games['home_team']) | set(games['away_team'])
    team_map = {name: id_ for id_, name in enumerate(team_names, start=1)}
    return team_map


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
    team_names = model.get_team_map(games)

    # Put the data into Stan format
    stan_data = {
        'n_games': len(games),
        'n_teams': len(team_map),
        'home_team': games['home_team'].replace(team_map),
        'away_team': games['away_team'].replace(team_map),
        'home_logit': games['home_win_logit'],
        'away_logit': games['away_win_logit']
    }

    # Fit and output estimates
    fit = model.optimizing(stan_data)

    return fit



if __name__ == '__main__':
    # Load the data
    games = pd.read_csv(os.path.join(
        os.path.dirname(__file__),
        'data/premier-league-all-books.csv'
    ))

    # Wrangle the data
    games['home_team'] = games['home_team'] + '-' + games['bookmaker'] + '-' + games['season'].astype(str)
    games['away_team'] = games['away_team'] + '-' + games['bookmaker'] + '-' + games['season'].astype(str)
    games = prepare_games(games)

    # Fit the model
    fit = run_stan_model(games)

    # Parse the output and save to file
    team_strength_records = []
    for name, i in team_map.items():
        team_strength_records.append({
            'team': name,
            'strength': fit['team_strength'][i-1]
        })
    team_strength = pd.DataFrame(team_strength_records)

    team_strength.to_csv(os.path.join(
        os.path.dirname(__file__),
        'data/fitted_strengths.csv'
    ), index=False, encoding='utf-8')
