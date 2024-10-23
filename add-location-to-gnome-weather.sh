#!/bin/bash
#Original developer: julianfairfax
#Original repository: https://gitlab.com/julianfairfax/scripts
#Description: This Script help you to add a location to Gnome Weather
#Dependency: Need to install "bc" alongside!

if [[ ! -z "$(which gnome-weather)" ]]; then
	system=1
fi

if [[ ! -z "$(flatpak list | grep org.gnome.Weather)" ]]; then
	flatpak=1
fi

if [[ ! $system == 1 && ! $flatpak == 1 ]]; then
	echo "GNOME Weather isn't installed"
	exit
fi

language=$(locale | sed -n 's/^LANG=\([^_]*\).*/\1/p')

if [[ ! -z "$*" ]]; then
	query="$*"
else
	read -p "Type the name of the location you want to add to GNOME Weather: " query
fi

query="$(echo $query | sed 's/ /+/g')"

request=$(curl "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1" -H "Accept-Language: $language" -s)

if [[ $request == "[]" ]]; then
	echo "No locations found, consider removing some search terms"
	exit
fi

read -p "If this is not the location you wanted, consider adding search terms
Are you sure you want to add $(echo $request | sed 's/.*"display_name":"//' | sed 's/".*//')? [y/n] : " answer

if [[ ! $answer == "y" ]]; then
	echo "Not adding location"
	exit
else
	echo "Adding location"
fi

id=$(echo $request | sed 's/.*"place_id"://' | sed 's/,.*//')

details=$(curl "https://nominatim.openstreetmap.org/details.php?place_id=$id&format=json" -s)

if [[ $details == *"name:$language"* ]]; then
	name=$(echo $details | sed "s/.*\"name:$language\": \"//" | sed 's/".*//')
else
	name=$(echo $details | sed 's/.*"name": "//' | sed 's/".*//')
fi

lat=$(echo $request | sed 's/.*"lat":"//' | sed 's/".*//')
lat=$(echo "$lat / (180 / 3.141592654)" | bc -l)

lon=$(echo $request | sed 's/.*"lon":"//' | sed 's/".*//')
lon=$(echo "$lon / (180 / 3.141592654)" | bc -l)

if [[ $system == 1 ]]; then
	locations=$(gsettings get org.gnome.Weather locations)
fi

if [[ $flatpak == 1 ]]; then
	locations=$(flatpak run --command=gsettings org.gnome.Weather get org.gnome.Weather locations)
fi

location="<(uint32 2, <('$name', '', false, [($lat, $lon)], @a(dd) [])>)>"

if [[ $system == 1 ]]; then
	if [[ ! $(gsettings get org.gnome.Weather locations) == "@av []" ]]; then
		gsettings set org.gnome.Weather locations "$(echo $locations | sed "s|>]|>, $location]|")"
	else
		gsettings set org.gnome.Weather locations "[$location]"
	fi
fi

if [[ $flatpak == 1 ]]; then
	if [[ ! $(flatpak run --command=gsettings org.gnome.Weather get org.gnome.Weather locations) == "@av []" ]]; then
		flatpak run --command=gsettings org.gnome.Weather set org.gnome.Weather locations "$(echo $locations | sed "s|>]|>, $location]|")"
	else
		flatpak run --command=gsettings org.gnome.Weather set org.gnome.Weather locations "[$location]"
	fi
fi
