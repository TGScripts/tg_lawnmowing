ESX = nil
ESX = exports["es_extended"]:getSharedObject()

RegisterServerEvent('tg_lawnmowing:pay')
AddEventHandler('tg_lawnmowing:pay', function(amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        xPlayer.addMoney(amount)
        TriggerClientEvent('tg_lawnmowing:tg_shownotification', source, tg_translate('job_reward', amount))
    end
end)