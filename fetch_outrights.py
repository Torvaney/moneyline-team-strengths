import datetime as dt
import os
import time

from bs4 import BeautifulSoup
import requests
import pandas as pd

PL_URL_STEM = 'https://www.oddschecker.com/football/english/premier-league/{}'


BOOKMAKER_MAP = {
    'B3': 'bet365',
    'SK': 'skybet',
    'LD': 'ladbrokes',
    'WH': 'william_hill',
    'SO': 'sportingbet',
    'FB': 'betfair',
    'P3': 'sun_bets',
    'PP': 'paddypower',
    'UN': 'unibet',
    'CE': 'coral',
    'FR': 'betfred',
    'BY': 'boyle_sports',
    'BL': 'blacktype',
    'PS': 'betstars',
    'WA': 'betway',
    'BB': 'betbright',
    'BW': 'bwin',
    'OE': '10bet',
    'MR': 'marathon',
    'EB': '188bet',
    'EE': '888sport',
    'SJ': 'stan_james',
    'VC': 'bet_victor',
    'WN': 'winner',
    'PE': 'sport_pesa',
    'BF': 'betfair_exchange',
    'BD': 'betdaq',
    'MA': 'matchbook'
}


def fetch_outrights(url):
    """ Fetch outright odds from oddschecker and return as a dataframe. """

    r = requests.get(url)
    page = BeautifulSoup(r.text, 'lxml')

    # Parse column names
    columns = page.select_one('.eventTableHeader')
    bookmaker_code = [c.attrs['data-bk'] for c in columns.select('.bookie-area')]

    odds = []
    rows = page.select_one('#t1')
    for row in rows.select('tr'):
        team = row.select_one('.nm').text
        for book, element in zip(bookmaker_code, row.select('.bc.bs.o')):
            price = float(element.attrs['data-odig'])
            odds.append({
                'date': dt.datetime.now().date(),
                'team': team,
                'bookmaker': BOOKMAKER_MAP[book],
                'odds': price if price != 0 else None
            })

    return pd.DataFrame(odds)


if __name__ == '__main__':
    for outright in ['winner', 'relegation']:
        odds = fetch_outrights(PL_URL_STEM.format(outright))
        # Save to file
        odds.to_csv(os.path.join(
            os.path.dirname(__file__),
            'data/outright_{}.csv'.format(outright)
        ), index=False, encoding='utf-8')
        time.sleep(2.5)
