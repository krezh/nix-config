import options from "options";
import { TodayIcon } from "./icon/index.js";
import { TodayStats } from "./stats/index.js";
import { TodayTemperature } from "./temperature/index.js";
import { Hourly } from "./hourly/index.js";
import { Weather } from "lib/types/weather.js";
import { DEFAULT_WEATHER } from "lib/types/defaults/weather.js";

const { key, interval, location } = options.menus.clock.weather;

const theWeather = Variable<Weather>(DEFAULT_WEATHER);

const WeatherWidget = () => {
    return Widget.Box({
        class_name: "calendar-menu-item-container weather",
        child: Widget.Box({
            class_name: "weather-container-box",
            setup: (self) => {
                Utils.merge(
                    [key.bind("value"), interval.bind("value"), location.bind("value")],
                    (weatherKey, weatherInterval, loc) => {
                        Utils.interval(weatherInterval, () => {
                            const formattedLocation = loc.replace(" ", "%20");
                            Utils.execAsync(
                                `curl "https://api.weatherapi.com/v1/forecast.json?key=${weatherKey}&q=${formattedLocation}&days=1&aqi=no&alerts=no"`,
                            )
                                .then((res) => {
                                    try {
                                        if (typeof res !== "string") {
                                            return theWeather.value = DEFAULT_WEATHER;
                                        }

                                        const parsedWeather = JSON.parse(res);

                                        if (Object.keys(parsedWeather).includes("error")) {
                                            return theWeather.value = DEFAULT_WEATHER;
                                        }

                                        return theWeather.value = parsedWeather;
                                    } catch (error) {
                                        theWeather.value = DEFAULT_WEATHER;
                                        console.error(`Failed to parse weather data: ${error}`);
                                    }
                                })
                                .catch((err) => {
                                    console.error(`Failed to fetch weather: ${err}`);
                                    theWeather.value = DEFAULT_WEATHER;
                                });
                        });
                    },
                );

                return (self.child = Widget.Box({
                    vertical: true,
                    hexpand: true,
                    children: [
                        Widget.Box({
                            class_name: "calendar-menu-weather today",
                            hexpand: true,
                            children: [
                                TodayIcon(theWeather),
                                TodayTemperature(theWeather),
                                TodayStats(theWeather),
                            ],
                        }),
                        Widget.Separator({
                            class_name: "menu-separator weather",
                        }),
                        Hourly(theWeather),
                    ],
                }));
            },
        }),
    });
};

export { WeatherWidget };
