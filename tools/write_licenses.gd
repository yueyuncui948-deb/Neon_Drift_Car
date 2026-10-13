extends SceneTree
func _initialize() -> void:
    var text := "Neon Drift — third-party notices\n\nGODOT ENGINE\n\n"
    text += Engine.get_license_text()+"\n\nTHIRD-PARTY COPYRIGHT NOTICES\n\n"
    text += JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\nTHIRD-PARTY LICENSE TEXTS\n\n"
    var licenses := Engine.get_license_info()
    for name in licenses:
        text += name+"\n"+str(licenses[name])+"\n\n"
    text += "NEON UI — SUBSET OF NOTO SANS CJK TC\n\n"
    text += FileAccess.get_file_as_string("res://assets/ui/FONT-LICENSE.txt")
    var output := FileAccess.open("res://docs/play/LICENSES.txt",FileAccess.WRITE)
    if output == null:
        quit(1)
        return
    output.store_string(text)
    output.close()
    print("Third-party notices written")
    quit(0)
