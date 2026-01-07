# Geospatial Extension for Mojo Grizzly DB
# Spatial queries and mapping support.

from math import sin, cos, sqrt, atan2, pi
from python import Python

struct Point:
    var lat: Float64
    var lon: Float64

    fn __init__(out self, lat: Float64, lon: Float64):
        self.lat = lat
        self.lon = lon

    fn distance_to(self, other: Point) -> Float64:
        # Haversine distance in km
        var dlat = (other.lat - self.lat) * pi / 180.0
        var dlon = (other.lon - self.lon) * pi / 180.0
        var a = sin(dlat/2)**2 + cos(self.lat * pi / 180.0) * cos(other.lat * pi / 180.0) * sin(dlon/2)**2
        var c = 2 * atan2(sqrt(a), sqrt(1-a))
        return 6371 * c  # Earth radius in km

struct Polygon:
    var points: List[Point]

    fn __init__(out self, points: List[Point]):
        self.points = points

    fn contains(self, point: Point) -> Bool:
        # Ray casting algorithm
        var inside = False
        var j = len(self.points) - 1
        for i in range(len(self.points)):
            if ((self.points[i].lon > point.lon) != (self.points[j].lon > point.lon)) and \
               (point.lat < (self.points[j].lat - self.points[i].lat) * (point.lon - self.points[i].lon) / (self.points[j].lon - self.points[i].lon) + self.points[i].lat):
                inside = not inside
            j = i
        return inside

fn init():
    print("Geospatial extension loaded. Spatial queries enabled.")