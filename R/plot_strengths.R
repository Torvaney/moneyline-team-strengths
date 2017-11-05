library(readr)
library(ggplot2)
library(dplyr)

# For aesthetic continuity
colours <- list(
  low = "#9ecae1",
  high = "#08519c"
)

ratings <- read_csv("data/fitted_strengths.csv") %>% 
  tidyr::separate(team, c("team", "bookmaker", "season"), sep = "-")

ratings %>% 
  mutate(season = as.numeric(season)) %>% 
  ggplot(aes(x = season, y = strength)) +
  geom_line(aes(group = bookmaker), alpha = 0.5, colour = colours$high) +
  geom_point(size = 0.2, alpha = 0.5, colour = colours$high) +
  facet_wrap(~ reorder(team, -strength), scales = "free_y") +
  scale_x_continuous(labels = format_season) +
  theme_minimal() +
  ggtitle("Premier League team strengths",
          "Multiple bookmakers") +
  xlab("Season") +
  ylab("")

# Find outlier book
# Looks like it's all Stan James
ratings %>% 
  filter(team == "Southampton",
         season == 2014) %>% 
  arrange(strength)

ratings %>% 
  filter(team == "Crystal Palace",
         season == 2014) %>% 
  arrange(strength)

ratings %>% 
  filter(team == "Liverpool",
         season == 2014) %>% 
  arrange(strength)


# Compare opening and closing lines
ratings %>% 
  filter(bookmaker %in% c("pinnacle", "pinnacle_closing")) %>% 
  tidyr::spread(bookmaker, strength) %>% 
  ggplot(aes(x = pinnacle, y = pinnacle_closing)) +
  geom_point()

ratings %>% 
  filter(bookmaker %in% c("pinnacle", "pinnacle_closing")) %>% 
  tidyr::spread(bookmaker, strength) %>% 
  mutate(diff = (pinnacle_closing - pinnacle)) %>% 
  group_by(diff > 0) %>% 
  arrange(desc(abs(diff))) %>% 
  slice(1:5) %>% 
  ggplot(aes(x = reorder(paste(team, season), diff), y = diff)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  facet_grid((diff < 0) ~ ., scales = "free")
