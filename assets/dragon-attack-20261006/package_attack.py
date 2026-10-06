"""Package the evaluated attack bake as a standalone Roblox KeyframeSequence.

Uses only the Python standard library. Does not open Blender or Roblox Studio.
Bone translations stay in authoring units; Roblox's Animator applies Model scale.
"""

from __future__ import annotations

import argparse
import hashlib
from itertools import count
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent
SIGNS = (-1.0, 1.0, -1.0)
IDENTITY = [[float(i == j) for j in range(4)] for i in range(4)]
REFERENTS = count()


def native_matrix(matrix):
    """Y180 * Blender bone-local delta * Y180, including translation."""
    result = [row[:] for row in IDENTITY]
    for row in range(3):
        for column in range(3):
            result[row][column] = matrix[row][column] * SIGNS[row] * SIGNS[column]
        result[row][3] = matrix[row][3] * SIGNS[row]
    return result


def property_value(properties, kind, name, value):
    element = ET.SubElement(properties, kind, name=name)
    element.text = str(value)
    return element


def add_item(parent, class_name, name):
    item = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{next(REFERENTS):08X}"})
    properties = ET.SubElement(item, "Properties")
    property_value(properties, "string", "Name", name)
    return item, properties


def add_cframe(properties, matrix):
    element = ET.SubElement(properties, "CoordinateFrame", name="CFrame")
    for axis, row in zip(("X", "Y", "Z"), range(3)):
        ET.SubElement(element, axis).text = format(matrix[row][3], ".17g")
    for row in range(3):
        for column in range(3):
            ET.SubElement(element, f"R{row}{column}").text = format(matrix[row][column], ".17g")


def add_pose(parent, name, matrix, weight):
    pose, properties = add_item(parent, "Pose", name)
    add_cframe(properties, matrix)
    property_value(properties, "float", "Weight", weight)
    property_value(properties, "token", "EasingStyle", 0)  # Linear.
    property_value(properties, "token", "EasingDirection", 0)
    return pose


def item_name(item):
    return item.find("./Properties/string[@name='Name']").text


def read_cframe(item):
    node = item.find("./Properties/CoordinateFrame[@name='CFrame']")
    result = [row[:] for row in IDENTITY]
    for axis, row in zip(("X", "Y", "Z"), range(3)):
        result[row][3] = float(node.find(axis).text)
    for row in range(3):
        for column in range(3):
            result[row][column] = float(node.find(f"R{row}{column}").text)
    return result


def matrix_error(left, right):
    return max(abs(left[row][column] - right[row][column]) for row in range(4) for column in range(4))


def determinant(matrix):
    a, b, c = [row[:3] for row in matrix[:3]]
    return a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])


def package(source_path, output_path, check_path):
    global REFERENTS
    REFERENTS = count()
    data = json.loads(source_path.read_text())
    bones = data["bones"]
    names = [bone["name"] for bone in bones]
    parents = {bone["name"]: bone["parent"] for bone in bones}
    frames = data["frames"]
    assert len(names) == len(set(names)) == 23
    assert [name for name in names if parents[name] is None] == ["FlightRoot"]
    assert data["revision"] == "Forward Swoop v3"
    assert data["fps"] == 60 and data["duration"] == 1.4 and len(frames) == 85
    assert data["loop"] is False and data["priority"] == "Action"
    for index, frame in enumerate(frames):
        assert abs(frame["time"] - index / 60) < 1e-12
        assert set(frame["poses"]) == set(names)
        assert all(math.isfinite(value) for matrix in frame["poses"].values() for row in matrix for value in row)
    assert data["markers"] == [{"name": "AttackContact", "time": 32 / 60}]

    document = ET.Element("roblox", version="4")
    sequence, properties = add_item(document, "KeyframeSequence", "Attack")
    property_value(properties, "bool", "Loop", "false")
    property_value(properties, "token", "Priority", 2)  # Enum.AnimationPriority.Action.

    def add_bone(parent_pose, name, poses):
        pose = add_pose(parent_pose, name, native_matrix(poses[name]), 1)
        for child in names:
            if parents[child] == name:
                add_bone(pose, child, poses)

    for frame in frames:
        keyframe, properties = add_item(sequence, "Keyframe", "Keyframe")
        property_value(properties, "float", "Time", format(frame["time"], ".17g"))
        wrapper = add_pose(keyframe, "DragonChickenMesh", IDENTITY, 0)
        add_bone(wrapper, "FlightRoot", frame["poses"])
        for marker in data["markers"]:
            if abs(marker["time"] - frame["time"]) < 1e-12:
                _, marker_properties = add_item(keyframe, "KeyframeMarker", marker["name"])
                property_value(marker_properties, "string", "Value", "")

    ET.indent(document, space="  ")
    ET.ElementTree(document).write(output_path, encoding="utf-8", xml_declaration=True)

    # Read the serialized artifact back, verifying structure, timing and transforms.
    loaded = ET.parse(output_path).getroot()
    sequences = loaded.findall("./Item[@class='KeyframeSequence']")
    assert len(sequences) == 1 and item_name(sequences[0]) == "Attack"
    sequence = sequences[0]
    assert sequence.find("./Properties/bool[@name='Loop']").text == "false"
    assert sequence.find("./Properties/token[@name='Priority']").text == "2"
    loaded_frames = sequence.findall("./Item[@class='Keyframe']")
    assert len(loaded_frames) == 85
    max_serialized_error = max_orthogonality_error = 0.0
    min_determinant, max_determinant = math.inf, -math.inf
    markers = []
    for source_frame, keyframe in zip(frames, loaded_frames):
        time = float(keyframe.find("./Properties/float[@name='Time']").text)
        assert time == source_frame["time"]
        wrappers = keyframe.findall("./Item[@class='Pose']")
        assert len(wrappers) == 1 and item_name(wrappers[0]) == "DragonChickenMesh"
        assert wrappers[0].find("./Properties/float[@name='Weight']").text == "0"
        assert matrix_error(read_cframe(wrappers[0]), IDENTITY) == 0
        parent_map = {child: parent for parent in wrappers[0].iter("Item") for child in parent.findall("./Item[@class='Pose']")}
        poses = list(wrappers[0].iter("Item"))[1:]
        assert len(poses) == 23 and {item_name(pose) for pose in poses} == set(names)
        for pose in poses:
            name = item_name(pose)
            expected_parent = parents[name] or "DragonChickenMesh"
            assert item_name(parent_map[pose]) == expected_parent
            assert pose.find("./Properties/float[@name='Weight']").text == "1"
            assert pose.find("./Properties/token[@name='EasingStyle']").text == "0"
            matrix = read_cframe(pose)
            max_serialized_error = max(max_serialized_error, matrix_error(matrix, native_matrix(source_frame["poses"][name])))
            max_orthogonality_error = max(max_orthogonality_error, max(abs(sum(matrix[k][i] * matrix[k][j] for k in range(3)) - float(i == j)) for i in range(3) for j in range(3)))
            det = determinant(matrix)
            min_determinant, max_determinant = min(min_determinant, det), max(max_determinant, det)
        markers.extend({"name": item_name(marker), "time": time} for marker in keyframe.findall("./Item[@class='KeyframeMarker']"))
    assert markers == data["markers"]
    assert max_serialized_error == 0 and max_orthogonality_error < 1e-5
    assert abs(min_determinant - 1) < 1e-5 and abs(max_determinant - 1) < 1e-5
    endpoint_error = max(matrix_error(frames[0]["poses"][name], frames[-1]["poses"][name]) for name in names)
    assert endpoint_error == 0

    check = {
        "status": "passed_local_xml_readback",
        "source": source_path.name,
        "sourceSha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "output": output_path.name,
        "outputSha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
        "sequence": "Attack", "revision": data["revision"], "loop": False, "priority": "Action", "priorityValue": 2,
        "fps": 60, "samples": 85, "duration": 1.4, "bonePosesPerSample": 23,
        "meshWrapper": "DragonChickenMesh", "markers": markers,
        "conversion": "Y180 * Blender bone-local delta * Y180; source-unit translations, no Model scale baked",
        "maxSerializedMatrixElementError": max_serialized_error,
        "maxRotationOrthogonalityError": max_orthogonality_error,
        "rotationDeterminantRange": [min_determinant, max_determinant],
        "entryExitMatrixElementError": endpoint_error,
        "studioImportVerified": False, "animationPublished": False, "gameplayHookedUp": False,
    }
    flight_path = Path("/Users/stevin/.codex/artifacts/dragon-chicken-roblox/flight-cycle.json")
    if flight_path.exists():
        flight = json.loads(flight_path.read_text())["frames"][0]["poses"]
        entry_error = max(matrix_error(frames[0]["poses"][name], flight[name]) for name in names)
        # Blender reevaluation can differ from the older bake by float roundoff.
        assert entry_error < 1e-6
        check["flightPhaseZeroMatrixElementError"] = entry_error
        check["flightComparisonSource"] = str(flight_path)
    check_path.write_text(json.dumps(check, indent=2) + "\n")
    print(json.dumps(check, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "attack-cycle.json")
    parser.add_argument("--output", type=Path, default=ROOT / "GalaxyDragon-Attack.rbxmx")
    parser.add_argument("--check", type=Path, default=ROOT / "export-check.json")
    arguments = parser.parse_args()
    package(arguments.source, arguments.output, arguments.check)
