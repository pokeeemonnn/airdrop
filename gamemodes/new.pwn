#include <a_samp>

#define AIRDROP_PLANE_ID 10757
#define AIRDROP_PACKAGE_ID 18849
#define AIRDROP_BAG_OBJECT 2919
#define AIRDROP_MAP_ICON 37
#define AIRDROP_COOLDOWN_MIN 60
#define AIRDROP_COOLDOWN_MAX 120
#define COLOR_FACTION 0x00FF00FF
#define MAX_PLAYERS 100

enum E_AIRDROP {
    bool:ACTIVE,
    PACKAGE_OBJECT,
    CARRIER_ID,
    PICKUP_ID,
    MAPICON,
    GANGZONE,
    CARRIER_MAPICON,
    Float:POS_X,
    Float:POS_Y,
    Float:POS_Z,
    ZONE_ID,
    TIMER,
    UPDATE_TIMER,
    CARRIER_TIMER,
    PLANE_OBJECT
}
new Airdrop[E_AIRDROP];

enum E_MAFIA_DELIVERY {
    Float:DELIVERY_X,
    Float:DELIVERY_Y,
    Float:DELIVERY_Z,
    Float:DELIVERY_SIZE
}
new MafiaDelivery[][E_MAFIA_DELIVERY] = {
    {-2556.0, 1320.0, 50.0, 3.0},
    {-1800.0, 2100.0, 50.0, 3.0},
    {-2700.0, 375.0, 50.0, 3.0},
    {-1560.0, -270.0, 50.0, 3.0}
};

enum E_AIRDROP_ZONE {
    ZONE_NAME[32],
    Float:MIN_X,
    Float:MIN_Y,
    Float:MAX_X,
    Float:MAX_Y
}
new AirdropZones[][E_AIRDROP_ZONE] = {
    {"Zone 1", -50.0, 1470.5, 50.0, 1570.5},
    {"Zone 2", -843.0, 2371.5, -743.0, 2471.5},
    {"Zone 3", -740.0, 1246.5, -640.0, 1346.5},
    {"Zone 4", -1361.0, 2456.5, -1261.0, 2556.5}
};

new CarrierCheckpoint[MAX_PLAYERS] = {-1, ...};
new Text3D:AirdropLabel = Text3D:INVALID_3DTEXT_ID;

forward StartAirdrop();
forward SpawnAirdropPlane();
forward DropAirdropPackage();
forward DestroyAirdropPlane();
forward UpdateCarrierMarker();

public OnGameModeInit() {
    SetGameModeText("Airdrop System");
    AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
    Airdrop[TIMER] = SetTimer("StartAirdrop", (AIRDROP_COOLDOWN_MIN + random(AIRDROP_COOLDOWN_MAX - AIRDROP_COOLDOWN_MIN)) * 60000, false);
    return 1;
}

public OnPlayerDisconnect(playerid, reason) {
    if(playerid == Airdrop[CARRIER_ID]) {
        ResetCarrier();
        CreateAirdropPickup();
    }
    if(CarrierCheckpoint[playerid] != -1) {
        DisablePlayerCheckpoint(playerid);
        CarrierCheckpoint[playerid] = -1;
    }
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason) {
    if(playerid == Airdrop[CARRIER_ID]) {
        new faction = GetPlayerFaction(playerid);
        new name[MAX_PLAYER_NAME];
        GetPlayerName(playerid, name, sizeof(name));

        ResetCarrier();
        CreateAirdropPickup();

        for(new i = 0; i < MAX_PLAYERS; i++) {
            if(IsPlayerConnected(i) && IsPlayerInMafiaFaction(i)) {
                new message[128];
                format(message, sizeof(message), "{%06x}%s потерял сумку. Заберите её и доставьте к особняку", COLOR_FACTION >>> 8, name);
                SendClientMessage(i, COLOR_FACTION, message);
            }
        }
    }
    return 1;
}

public OnPlayerEnterCheckpoint(playerid) {
    if(Airdrop[ACTIVE] && playerid == Airdrop[CARRIER_ID] && CarrierCheckpoint[playerid] != -1) {
        new faction = GetPlayerFaction(playerid);
        new factionName[32], playerName[MAX_PLAYER_NAME];
        GetFactionName(faction, factionName);
        GetPlayerName(playerid, playerName, sizeof(playerName));

        AddFactionBankMoney(faction, 200000);
        AddFactionMaterials(faction, 50000);
        AddFactionRating(faction, 1500);

        GivePlayerMoney(playerid, 100000);
        SetPlayerScore(playerid, GetPlayerScore(playerid) + 1500);

        for(new i = 0; i < MAX_PLAYERS; i++) {
            if(IsPlayerConnected(i) && IsPlayerInMafiaFaction(i)) {
                new msg[128];
                format(msg, sizeof(msg), "{%06x}Завершено событие: \"Аирдроп\". Груз был доставлен фракцией %s", COLOR_FACTION >>> 8, factionName);
                SendClientMessage(i, COLOR_FACTION, msg);

                if(GetPlayerFaction(i) == faction) {
                    format(msg, sizeof(msg), "{%06x}Ваша фракция получила: 200000$ на банк мафии / 1500 рейтинга / 50000 материалов", COLOR_FACTION >>> 8);
                    SendClientMessage(i, COLOR_FACTION, msg);

                    format(msg, sizeof(msg), "{%06x}Игрок %s получил за доставку груза: 100000$ / 1500 рейтинга", COLOR_FACTION >>> 8, playerName);
                    SendClientMessage(i, COLOR_FACTION, msg);
                }
            }
        }

        ResetAirdrop();
    }
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid) {
    if(Airdrop[ACTIVE] && pickupid == Airdrop[PICKUP_ID] && IsPlayerInMafiaFaction(playerid)) {
        if(Airdrop[CARRIER_ID] != -1) return 1;

        Airdrop[CARRIER_ID] = playerid;
        DestroyPickup(Airdrop[PICKUP_ID]);
        Airdrop[PICKUP_ID] = -1;
        RemovePlayerMapIcon(playerid, Airdrop[MAPICON]);
        Airdrop[MAPICON] = -1;

        SetPlayerAttachedObject(playerid, 0, AIRDROP_BAG_OBJECT, 5, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0);
        Airdrop[CARRIER_MAPICON] = SetPlayerMapIcon(playerid, 0, 0.0, 0.0, 0.0, AIRDROP_MAP_ICON, 0, MAPICON_GLOBAL);
        UpdateCarrierMarker();
        Airdrop[CARRIER_TIMER] = SetTimer("UpdateCarrierMarker", 3000, true);

        new faction = GetPlayerFaction(playerid);
        SetPlayerCheckpoint(playerid,
            MafiaDelivery[faction-1][DELIVERY_X],
            MafiaDelivery[faction-1][DELIVERY_Y],
            MafiaDelivery[faction-1][DELIVERY_Z],
            MafiaDelivery[faction-1][DELIVERY_SIZE]);
        CarrierCheckpoint[playerid] = 1;

        new factionName[32], playerName[MAX_PLAYER_NAME];
        GetFactionName(faction, factionName);
        GetPlayerName(playerid, playerName, sizeof(playerName));

        for(new i = 0; i < MAX_PLAYERS; i++) {
            if(IsPlayerConnected(i) && IsPlayerInMafiaFaction(i)) {
                new msg[128];
                format(msg, sizeof(msg), "{%06x}Фракция %s перехватила сумку. Поймайте и отберите сумку у %s", COLOR_FACTION >>> 8, factionName, playerName);
                SendClientMessage(i, COLOR_FACTION, msg);
            }
        }
    }
    return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys) {
    if(Airdrop[ACTIVE] && (newkeys & KEY_WALK) && IsPlayerInRangeOfPoint(playerid, 3.0, Airdrop[POS_X], Airdrop[POS_Y], Airdrop[POS_Z])) {
        if(!IsPlayerInMafiaFaction(playerid)) return 0;
        if(Airdrop[CARRIER_ID] != -1) return 0;

        Airdrop[CARRIER_ID] = playerid;
        DestroyObject(Airdrop[PACKAGE_OBJECT]);
        Airdrop[PACKAGE_OBJECT] = -1;
        RemovePlayerMapIcon(playerid, Airdrop[MAPICON]);
        Airdrop[MAPICON] = -1;
        GangZoneDestroy(Airdrop[GANGZONE]);
        Airdrop[GANGZONE] = -1;

        if(AirdropLabel != Text3D:INVALID_3DTEXT_ID) {
            Delete3DTextLabel(AirdropLabel);
            AirdropLabel = Text3D:INVALID_3DTEXT_ID;
        }

        SetPlayerAttachedObject(playerid, 0, AIRDROP_BAG_OBJECT, 5, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0);
        Airdrop[CARRIER_MAPICON] = SetPlayerMapIcon(playerid, 0, 0.0, 0.0, 0.0, AIRDROP_MAP_ICON, 0, MAPICON_GLOBAL);
        UpdateCarrierMarker();
        Airdrop[CARRIER_TIMER] = SetTimer("UpdateCarrierMarker", 3000, true);

        new faction = GetPlayerFaction(playerid);
        SetPlayerCheckpoint(playerid,
            MafiaDelivery[faction-1][DELIVERY_X],
            MafiaDelivery[faction-1][DELIVERY_Y],
            MafiaDelivery[faction-1][DELIVERY_Z],
            MafiaDelivery[faction-1][DELIVERY_SIZE]);
        CarrierCheckpoint[playerid] = 1;

        new factionName[32], playerName[MAX_PLAYER_NAME];
        GetFactionName(faction, factionName);
        GetPlayerName(playerid, playerName, sizeof(playerName));

        for(new i = 0; i < MAX_PLAYERS; i++) {
            if(IsPlayerConnected(i) && IsPlayerInMafiaFaction(i)) {
                new msg[128];
                format(msg, sizeof(msg), "{%06x}Действует событие: \"Аирдроп\". Груз подобрала фракция %s", COLOR_FACTION >>> 8, factionName);
                SendClientMessage(i, COLOR_FACTION, msg);

                format(msg, sizeof(msg), "{%06x}Поймайте и отберите сумку у %s", COLOR_FACTION >>> 8, playerName);
                SendClientMessage(i, COLOR_FACTION, msg);
            }
        }
    }
    return 1;
}

public StartAirdrop() {
    if(Airdrop[ACTIVE]) return;

    Airdrop[ACTIVE] = true;
    new zone = random(sizeof(AirdropZones));
    Airdrop[ZONE_ID] = zone;

    Airdrop[POS_X] = (AirdropZones[zone][MIN_X] + AirdropZones[zone][MAX_X]) / 2.0;
    Airdrop[POS_Y] = (AirdropZones[zone][MIN_Y] + AirdropZones[zone][MAX_Y]) / 2.0;
    Airdrop[POS_Z] = 0.0;

    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(IsPlayerConnected(i)) {
            Airdrop[MAPICON] = SetPlayerMapIcon(i, 0, Airdrop[POS_X], Airdrop[POS_Y], Airdrop[POS_Z], AIRDROP_MAP_ICON, 0, MAPICON_GLOBAL);
            Airdrop[GANGZONE] = GangZoneCreate(AirdropZones[zone][MIN_X], AirdropZones[zone][MIN_Y], AirdropZones[zone][MAX_X], AirdropZones[zone][MAX_Y]);
            GangZoneShowForPlayer(i, Airdrop[GANGZONE], 0x00FF00FF);

            if(IsPlayerInMafiaFaction(i)) {
                new msg[128];
                format(msg, sizeof(msg), "{%06x}Начато событие: \"Аирдроп\". Груз будет сброшен в районе %s", COLOR_FACTION >>> 8, AirdropZones[zone][ZONE_NAME]);
                SendClientMessage(i, COLOR_FACTION, msg);
                SendClientMessage(i, COLOR_FACTION, "Груз будет выброшен через 10 минут. Установлена метка на карте");
            }
        }
    }

    SetTimer("SpawnAirdropPlane", 600000, false);
}

public SpawnAirdropPlane() {
    new Float:startX = Airdrop[POS_X] - 500.0;
    new Float:startY = Airdrop[POS_Y] - 500.0;
    new Float:startZ = 300.0;

    Airdrop[PLANE_OBJECT] = CreateObject(AIRDROP_PLANE_ID, startX, startY, startZ, 0.0, 0.0, 0.0);
    MoveObject(Airdrop[PLANE_OBJECT], Airdrop[POS_X], Airdrop[POS_Y], startZ, 50.0);

    SetTimer("DropAirdropPackage", 5000, false);
    SetTimer("DestroyAirdropPlane", 15000, false);
}

public DropAirdropPackage() {
    new Float:x = Airdrop[POS_X];
    new Float:y = Airdrop[POS_Y];
    new Float:z = 150.0;

    Airdrop[PACKAGE_OBJECT] = CreateObject(AIRDROP_PACKAGE_ID, x, y, z, 0.0, 0.0, 0.0);
    MoveObject(Airdrop[PACKAGE_OBJECT], x, y, Airdrop[POS_Z] + 1.0, 5.0);

    AirdropLabel = Create3DTextLabel("{FFFFFF}Сброшенная сумка\nНажмите {FF0000}L.ALT{FFFFFF}, чтобы подобрать сумку",
        0xFFFFFFFF, x, y, z, 15.0, 0, 0);

    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(IsPlayerConnected(i) && IsPlayerInMafiaFaction(i)) {
            SendClientMessage(i, COLOR_FACTION, "Действует событие: \"Аирдроп\". Груз был сброшен в районе");
            SendClientMessage(i, COLOR_FACTION, "Подберите груз и доставьте к особняку мафии");
        }
    }
}

public DestroyAirdropPlane() {
    DestroyObject(Airdrop[PLANE_OBJECT]);
    Airdrop[PLANE_OBJECT] = -1;
}

public UpdateCarrierMarker() {
    if(Airdrop[CARRIER_ID] == -1) {
        KillTimer(Airdrop[CARRIER_TIMER]);
        return;
    }

    new Float:x, Float:y, Float:z;
    GetPlayerPos(Airdrop[CARRIER_ID], x, y, z);
    SetPlayerMapIcon(Airdrop[CARRIER_ID], 0, x, y, z, AIRDROP_MAP_ICON, 0, MAPICON_GLOBAL);
}

CreateAirdropPickup() {
    new Float:x, Float:y, Float:z;
    GetPlayerPos(Airdrop[CARRIER_ID], x, y, z);

    Airdrop[PICKUP_ID] = CreatePickup(AIRDROP_BAG_OBJECT, 1, x, y, z);
    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(IsPlayerConnected(i)) {
            SetPlayerMapIcon(i, 1, x, y, z, AIRDROP_MAP_ICON, 0, MAPICON_GLOBAL);
        }
    }
}

ResetCarrier() {
    if(Airdrop[CARRIER_ID] != -1) {
        RemovePlayerAttachedObject(Airdrop[CARRIER_ID], 0);
        if(CarrierCheckpoint[Airdrop[CARRIER_ID]] != -1) {
            DisablePlayerCheckpoint(Airdrop[CARRIER_ID]);
            CarrierCheckpoint[Airdrop[CARRIER_ID]] = -1;
        }
        RemovePlayerMapIcon(Airdrop[CARRIER_ID], 0);
        Airdrop[CARRIER_ID] = -1;
    }
    if(Airdrop[CARRIER_TIMER] != -1) {
        KillTimer(Airdrop[CARRIER_TIMER]);
        Airdrop[CARRIER_TIMER] = -1;
    }
}

ResetAirdrop() {
    Airdrop[ACTIVE] = false;

    if(Airdrop[PACKAGE_OBJECT] != -1) {
        DestroyObject(Airdrop[PACKAGE_OBJECT]);
        Airdrop[PACKAGE_OBJECT] = -1;
    }
    if(Airdrop[PICKUP_ID] != -1) {
        DestroyPickup(Airdrop[PICKUP_ID]);
        Airdrop[PICKUP_ID] = -1;
    }

    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(IsPlayerConnected(i)) {
            RemovePlayerMapIcon(i, 0);
            RemovePlayerMapIcon(i, 1);
            GangZoneHideForPlayer(i, Airdrop[GANGZONE]);
        }
    }

    if(Airdrop[GANGZONE] != -1) {
        GangZoneDestroy(Airdrop[GANGZONE]);
        Airdrop[GANGZONE] = -1;
    }

    if(AirdropLabel != Text3D:INVALID_3DTEXT_ID) {
        Delete3DTextLabel(AirdropLabel);
        AirdropLabel = Text3D:INVALID_3DTEXT_ID;
    }

    if(Airdrop[PLANE_OBJECT] != -1) {
        DestroyObject(Airdrop[PLANE_OBJECT]);
        Airdrop[PLANE_OBJECT] = -1;
    }

    ResetCarrier();
    Airdrop[TIMER] = SetTimer("StartAirdrop", (AIRDROP_COOLDOWN_MIN + random(AIRDROP_COOLDOWN_MAX - AIRDROP_COOLDOWN_MIN)) * 60000, false);
}

stock bool:IsPlayerInMafiaFaction(playerid) {
    new faction = GetPlayerFaction(playerid);
    return (faction >= 1 && faction <= 4);
}
public OnGameModeExit() {
    ResetAirdrop();
    return 1;
}

public OnPlayerRequestClass(playerid, classid) {
    SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
    SetPlayerCameraPos(playerid, 1958.3783, 1343.1572, 15.3746);
    SetPlayerCameraLookAt(playerid, 1958.3783, 1343.1572, 15.3746);
    return 1;
}

public OnPlayerConnect(playerid) {
    return 1;
}

public OnPlayerSpawn(playerid) {
    return 1;
}

public OnVehicleSpawn(vehicleid) {
    return 1;
}

public OnVehicleDeath(vehicleid, killerid) {
    return 1;
}

public OnPlayerText(playerid, text[]) {
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[]) {
    if (strcmp("/mycommand", cmdtext, true, 10) == 0) {
        return 1;
    }
    return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger) {
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid) {
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate) {
    return 1;
}

public OnPlayerLeaveCheckpoint(playerid) {
    return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid) {
    return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid) {
    return 1;
}

public OnRconCommand(cmd[]) {
    return 1;
}

public OnPlayerRequestSpawn(playerid) {
    return 1;
}

public OnObjectMoved(objectid) {
    return 1;
}

public OnPlayerObjectMoved(playerid, objectid) {
    return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid) {
    return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid) {
    return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2) {
    return 1;
}

public OnPlayerSelectedMenuRow(playerid, row) {
    return 1;
}

public OnPlayerExitedMenu(playerid) {
    return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid) {
    return 1;
}

public OnRconLoginAttempt(ip[], password[], success) {
    return 1;
}

public OnPlayerUpdate(playerid) {
    return 1;
}

public OnPlayerStreamIn(playerid, forplayerid) {
    return 1;
}

public OnPlayerStreamOut(playerid, forplayerid) {
    return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid) {
    return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid) {
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source) {
    return 1;
}

stock GetPlayerFaction(playerid) {
    return 0;
}

stock GetFactionName(factionid, name[]) {
    format(name, 32, "Mafia %d", factionid);
    return 1;
}

stock AddFactionBankMoney(factionid, amount) {
    return 1;
}

stock AddFactionMaterials(factionid, amount) {
    return 1;
}

stock AddFactionRating(factionid, amount) {
    return 1;
}

main() {}
