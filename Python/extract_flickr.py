import requests
import json
from datetime import datetime
import shapefile
from shapely.geometry import Point, shape
import argparse
import os

def validate_dates(start_date, end_date):
    """Validate date inputs and return formatted strings"""
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
        
        if start > end:
            raise ValueError("Start date cannot be after end date")
            
        return start_date, end_date
    except ValueError as e:
        raise ValueError(f"Invalid date format. Use YYYY-MM-DD. Error: {str(e)}")

def load_shapefile(shapefile_path):
    """Load shapefile and validate its existence"""
    if not os.path.exists(shapefile_path):
        raise FileNotFoundError(f"Shapefile not found at {shapefile_path}")
    
    try:
        sf = shapefile.Reader(shapefile_path)
        shapes = sf.shapes()
        return [shape(s) for s in shapes], sf.bbox
    except Exception as e:
        raise ValueError(f"Error reading shapefile: {str(e)}")

def is_point_in_shape(lat, lon, shapes):
    """Check if a point is within any of the shapes"""
    point = Point(lon, lat)
    return any(s.contains(point) for s in shapes)

def get_flickr_photos(api_key, bbox, min_date, max_date, page=1):
    """Make API request to Flickr with pagination"""
    url = (f"https://www.flickr.com/services/rest/?method=flickr.photos.search"
           f"&api_key={api_key}&bbox={bbox}&extras=geo,date_taken,date_upload,owner_name"
           f"&has_geo=1&format=json&nojsoncallback=1&per_page=500"
           f"&min_taken_date={min_date}&max_taken_date={max_date}&page={page}")
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        raise ConnectionError(f"Flickr API request failed: {str(e)}")

def get_all_photos_in_shape(api_key, shapes, bbox, min_date, max_date):
    """Retrieve all photos within date range and shape with pagination"""
    all_photos = []
    page = 1
    total_pages = 1  # Will be updated after first request
    
    while page <= total_pages:
        data = get_flickr_photos(api_key, bbox, min_date, max_date, page)
        
        if 'photos' not in data:
            print("Error in API response:", data)
            break
            
        total_pages = data['photos']['pages']
        
        for photo in data['photos']['photo']:
            try:
                lat = float(photo['latitude'])
                lon = float(photo['longitude'])
                if is_point_in_shape(lat, lon, shapes):
                    all_photos.append(photo)
            except KeyError:
                continue
        
        print(f"Processed page {page}/{total_pages}... Found {len(all_photos)} photos so far")
        page += 1
        
        # Be polite to the API - add small delay between requests
        if page <= total_pages:
            time.sleep(0.5)
    
    return all_photos

def export_to_file(photos, filename):
    """Export results to CSV file"""
    with open(filename, 'w', encoding='utf-8') as file:
        file.write("ID;Latitude;Longitude;Date_Taken;Date_Upload;Owner_Name;URL\n")
        for photo in photos:
            url = f"https://www.flickr.com/photos/{photo['owner']}/{photo['id']}"
            file.write(f"{photo['id']};{photo['latitude']};{photo['longitude']};{photo['datetaken']};{photo['dateupload']};{photo['ownername']}\n")

def main():
    parser = argparse.ArgumentParser(description="Export Flickr photos within a shapefile boundary and date range")
    parser.add_argument("--api_key", required=True, help="Flickr API key")
    parser.add_argument("--shapefile", required=True, help="Path to shapefile (.shp)")
    parser.add_argument("--start_date", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end_date", required=True, help="End date (YYYY-MM-DD)")
    parser.add_argument("--output", help="Output filename (default: flickr_photos_<timestamp>.txt)")
    
    args = parser.parse_args()
    
    # Validate inputs
    min_date, max_date = validate_dates(args.start_date, args.end_date)
    shapes, bbox = load_shapefile(args.shapefile)
    bbox_str = f"{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}"
    
    # Get photos
    print(f"Searching for photos between {min_date} and {max_date} within shapefile boundary...")
    photos = get_all_photos_in_shape(args.api_key, shapes, bbox_str, min_date, max_date)
    
    # Create output filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = args.output or f"flickr_photos_{timestamp}.txt"
    
    # Export results
    export_to_file(photos, output_file)
    print(f"\nSuccessfully exported {len(photos)} photos to {output_file}")

if __name__ == "__main__":
    import time  # For the API delay
    main()
