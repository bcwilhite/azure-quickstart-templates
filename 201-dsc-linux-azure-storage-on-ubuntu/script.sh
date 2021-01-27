echo "Move Pending.mof to configuration store..."
mv ./Pending.mof /etc/opt/omi/conf/dsc/configuration/Pending.mof
echo "Move Pending.mof to configuration store... Complete"
echo "Execute Register.py --RefreshMode Push --ConfigurationMode ApplyOnly..."
/opt/microsoft/dsc/Scripts/Register.py --RefreshMode Push --ConfigurationMode ApplyOnly
echo "Execute Register.py --RefreshMode Push --ConfigurationMode ApplyOnly... Complete"
echo "Execute PerformRequiredConfigurationChecks.py to apply the Pending.mof configuration..."
/opt/microsoft/dsc/Scripts/PerformRequiredConfigurationChecks.py
echo "Execute PerformRequiredConfigurationChecks.py to apply the Pending.mof configuration... Complete"