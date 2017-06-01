<%@ WebHandler Language="C#" Class="SetRequestAttributesHandler" %>

using System;
using System.IO;
using System.Xml;
using System.Net;
using System.Web;
using MarvalSoftware.UI.WebUI.ServiceDesk.RFP.Plugins;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.Xml.Serialization;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using MarvalSoftware;

/// <summary>
/// Set Request Attributes Plugin Handler
/// </summary>
public class SetRequestAttributesHandler : PluginHandler
{
    public override bool IsReusable { get { return false; } }

    private string mSMBaseUrl { get { return string.Format("{0}://{1}{2}{3}", HttpContext.Current.Request.Url.Scheme, HttpContext.Current.Request.Url.Host, HttpContext.Current.Request.Url.Port == 80 || HttpContext.Current.Request.Url.Port == 443 ? "" : string.Format(":{0}",HttpContext.Current.Request.Url.Port) , MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath); } }
    private string pluginActionMessageKey { get { return this.GlobalSettings["Rules Action Message"]; } }
    private string mSMWSEAdr { get { return this.GlobalSettings["MSM WSE Address"]; } }
    private string mSMWSEEncUsr { get { return this.GlobalSettings["MSM WSE User Name"]; } }
    private string mSMWSEEncPwd { get { return this.GlobalSettings["MSM WSE Password"]; } }

    /// <summary>
    /// Main Request Handler
    /// </summary>
    public override void HandleRequest(HttpContext context)
    {
        if (context.Request.HttpMethod == "GET")
        {
            string actionMessageKey = context.Request.Params["ActionMessageKey"] ?? string.Empty;
            string requestId = context.Request.Params["RequestID"] ?? string.Empty;
            if (string.IsNullOrWhiteSpace(actionMessageKey)) context.Response.Write(JsonHelper.ToJSON(pluginActionMessageKey));
            else context.Response.Write(JsonHelper.ToJSON(getPluginRulesContent(actionMessageKey, requestId)));
        }
    }

    /// <summary>
    /// Return Action Message Content
    /// </summary>
    private string getPluginRulesContent(string msgKeys, string reqId)
    {
        jsonRulesObject pluginRules = new jsonRulesObject();
        List<Rule> pluginRulesList = new List<Rule>();
        if (string.IsNullOrEmpty(msgKeys)) return string.Empty;
        try
        {
            foreach (string msgKey in msgKeys.Split(','))
            {
                string messageContent = getActionMessageContent(msgKey, reqId);
                if (!string.IsNullOrEmpty(messageContent))
                {
                    // return JsonHelper.replaceWildcards(messageContent);
                    jsonRulesObject pluginRulesTmp = JsonHelper.DeserializeJSONObject<jsonRulesObject>(messageContent);
                    //return "Plugin Rules parsed successfully";
                    if (pluginRulesTmp != null && pluginRulesTmp.rules != null && pluginRulesTmp.rules.Length > 0)
                    {
                        foreach (var pr in pluginRulesTmp.rules)
                        {
                            //return string.Format("Processing rule {0}...",pr.name);
                            List<Action> newActions = new List<Action>();
                            foreach (var act in pr.actions)
                            {
                                //return string.Format("Processing action {0}...", act.action);
                                if (act.action == "applySetRequestAttributesXMLMessage")
                                {
                                    try
                                    {
                                        //return string.Format("Getting XML message {0}...", act.id);
                                        string setRequestAttributeActions = getActionMessageContent(string.Format("~{0}", act.id), reqId);
                                        if (!string.IsNullOrEmpty(setRequestAttributeActions))
                                        {
                                            //return string.Format("XML message content: {0}...", setRequestAttributeActions);
                                            SetRequestAttributesInput setRequestAttributeActionsMessage = XmlHelper.DeserializeXMLObject<SetRequestAttributesInput>(setRequestAttributeActions);
                                            //return "XML Message deserialized successfully.";
                                            if (setRequestAttributeActionsMessage != null)
                                            {
                                                foreach (RequestAttribute at in setRequestAttributeActionsMessage.Attributes)
                                                {
                                                    newActions.Add(new Action() { action = "set", type = "attr", id = at.AttributeID, value = at.AttributeValue, _override = false });
                                                }
                                            }
                                        }
                                    }
                                    catch (WebException ex)
                                    {
                                        return string.Format("XML Message deserialization exception! {0}",ex.Message);
                                    }
                                }
                                else
                                {
                                    newActions.Add(act);
                                }
                            }
                            pr.actions = newActions.ToArray();
                            pluginRulesList.Add(pr);
                        }
                    }
                }
            }
            pluginRules.rules = pluginRulesList.ToArray();
        }
        catch (WebException ex)
        {
            return string.Format("Error parsing plugin rules! {0}", ex.Message);
        }
        return JsonHelper.ToJSON(pluginRules);
    }

    /// <summary>
    /// Return Action Message Content
    /// </summary>
    private string getActionMessageContent(string msgKey, string reqId)
    {
        string messageContent = string.Empty;
        if (string.IsNullOrEmpty(msgKey)) return messageContent;
        try
        {
            HttpWebRequest request = CreateWebRequest(this.mSMWSEAdr, "http://www.marvalbaltic.lt/MSM/WebServiceExtensions/GetActionMessages", CreateSoapEnvelope(this.mSMWSEEncUsr, this.mSMWSEEncPwd, msgKey));
            string response = ProcessRequest(request);
            if (!string.IsNullOrEmpty(response))
            {
                XmlDocument soapResponse = new XmlDocument();
                soapResponse.LoadXml(XmlHelper.EscapeEscapeChar(response));
                XmlNodeList nodes = soapResponse.GetElementsByTagName("MSMActionMessage");
                if (nodes.Count == 1) messageContent = nodes[0]["Content"].InnerText;
                //if (!string.IsNullOrEmpty(messageContent))
                //{
                //    //int rid;
                //    //if (Int32.TryParse(reqId, out rid)) messageContent = processMessageRazor(messageContent, rid);
                //    //else messageContent = processMessageRazor(messageContent, 1);
                //}
            }
        }
        catch (WebException ex)
        {
            return string.Format("Error getting Action Message content! {0}", ex.Message);
        }
        return messageContent;
    }

    private string processMessageRazor(string MessageContent, int? RequestId)
    {

        string processedMessage = string.Empty;
        //int num;
        //int num1;
        //(new MarvalSoftware.ServiceDesk.Facade.RequestManagementFacade()).FindRequest(RequestId, out num, out num1);
        try
        {
            bool flag = false;
            if (RequestId != null)
            {
                MarvalSoftware.ServiceDesk.ServiceSupport.Request msmRequest = (new MarvalSoftware.ServiceDesk.Facade.AdminFacade()).ViewRazorTemplateRequestObject((int)RequestId);
                processedMessage = (new RazorHelper()).Render(MessageContent, msmRequest, out flag);
            }
            else
            {
                processedMessage = MessageContent;
                //processedMessage = (new RazorHelper()).Render(MessageContent, null);
            }

            if (flag)
            {
                throw new WebException(processedMessage);
            }
        }
        catch (WebException exception)
        {
            processedMessage = exception.Message;
        }
        return processedMessage;
    }

    //Generic Methods

    /// <summary>
    /// Creates web request SOAP envelope
    /// </summary>
    /// <param name="usr">WSE User name</param>
    /// <param name="pwd">WSE Password</param>
    /// <param name="msgId">Message ID</param>
    /// <returns>The XmlDocument ready to be sent</returns>
    private XmlDocument CreateSoapEnvelope(string Usr, string Pwd, string MsgKey)
    {
        int msgId = 0;
        if (MsgKey.Length > 1 && MsgKey[0] == '~' && int.TryParse(MsgKey.Substring(1), out msgId)) MsgKey = string.Format("id={0}", msgId);
        else MsgKey = string.Format("name={0}", MsgKey);
        XmlDocument soapEnvelop = new XmlDocument();
        soapEnvelop.LoadXml(string.Format(
@"<soapenv:Envelope xmlns:soapenv=""http://schemas.xmlsoap.org/soap/envelope/"" xmlns:web=""http://www.marvalbaltic.lt/MSM/WebServiceExtensions/"">
    <soapenv:Header xmlns:soapenv=""http://schemas.xmlsoap.org/soap/envelope/"" />
    <soapenv:Body>
    <web:GetActionMessages>
      <web:username>{0}</web:username>
      <web:password>{1}</web:password>
      <web:sessionKey></web:sessionKey>
      <web:extraFilter>{2}</web:extraFilter>
    </web:GetActionMessages>
  </soapenv:Body>
</soapenv:Envelope>"
, Usr, Pwd, MsgKey));
        return soapEnvelop;
    }

    /// <summary>
    /// Builds a HttpWebRequest
    /// </summary>
    /// <param name="url">The url for request</param>
    /// <param name="body">The body for the request</param>
    /// <param name="method">The verb for the request</param>
    /// <returns>The HttpWebRequest ready to be processed</returns>
    private HttpWebRequest CreateWebRequest(string url = null, string action = null, XmlDocument soapEnvelopeXml = null)
    {
        try
        {
            HttpWebRequest webRequest = (HttpWebRequest)WebRequest.Create(url);
            webRequest.Headers.Add("SOAPAction", action);
            webRequest.ContentType = "text/xml;charset=UTF-8";
            webRequest.Accept = "text/xml";
            webRequest.Method = "POST";
            using (Stream stream = webRequest.GetRequestStream()) { soapEnvelopeXml.Save(stream); }
            return webRequest;
        }
        catch { }
        return null;
    }

    /// <summary>
    /// Proccess a HttpWebRequest
    /// </summary>
    /// <param name="request">The HttpWebRequest</param>
    /// <returns>Process Response</returns>
    private string ProcessRequest(HttpWebRequest request)
    {
        try
        {
            if (request == null) return string.Empty;
            using (WebResponse response = request.GetResponse())
            {
                using (StreamReader rd = new StreamReader(response.GetResponseStream()))
                {
                    return rd.ReadToEnd();
                }
            }
        }
        catch { }
        return string.Empty;
    }

    private class jsonRulesObject
    {
        public Rule[] rules { get; set; }
    }

    private class Rule
    {
        public string name { get; set; }
        public Condition[] conditions { get; set; }
        public Action[] actions { get; set; }
    }

    private class Condition
    {
        public string type { get; set; }
        public object value { get; set; }
        public object id { get; set; }
    }

    private class Action
    {
        public string action { get; set; }
        public string type { get; set; }
        public int id { get; set; }
        public string value { get; set; }
        public bool _override { get; set; }
    }


    public class SetRequestAttributesInput
    {
        public string RequestID { get; set; }
        public string RequestNumber { get; set; }
        public string FullRequestNumber { get; set; }
        public List<RequestAttribute> Attributes { get; set; }
    }

    public class RequestAttribute
    {
        public int AttributeID { get; set; }
        public string AttributeValue { get; set; }
    }


}

/// <summary>
/// JsonHelper Functions
/// </summary>
public static class JsonHelper
{
    public static string replaceLBs(string jsonString)
    {
        return Regex.Replace(jsonString, @"\""[^\""]*?[\n\r]+[^\""]*?\""", m => Regex.Replace(m.Value, @"[\n\r]", "\\n"));
    }
    public static string replaceWildcards(string jsonString)
    {
        return jsonString.Replace("\\n", "").Replace("\\\"", "\"");
    }
    public static string ToJSON(object obj)
    {
        return JsonConvert.SerializeObject(obj);
    }
    public static string SerializeJSONObject<T>(this T JsonObjectToSerialize)
    {
        JsonSerializerSettings jsonSettings = new JsonSerializerSettings()
        {
            TypeNameHandling = TypeNameHandling.Objects
        };
        //jsonSettings.TypeNameHandling = TypeNameHandling.Objects;
        //jsonSettings.MetadataPropertyHandling = MetadataPropertyHandling.Default;
        return JsonConvert.SerializeObject(JsonObjectToSerialize);
        //return JsonConvert.SerializeObject(JsonObjectToSerialize, Newtonsoft.Json.Formatting.Indented, jsonSettings);
    }
    public static T DeserializeJSONObject<T>(this string JsonStringToDeserialize)
    {

        JsonSerializerSettings jsonSettings = new JsonSerializerSettings()
        {
            TypeNameHandling = TypeNameHandling.Objects
        };
        //jsonSettings.TypeNameHandling = TypeNameHandling.Objects;
        //jsonSettings.MetadataPropertyHandling = MetadataPropertyHandling.Default;
        JsonSerializer serializer = new JsonSerializer();
        return JsonConvert.DeserializeObject<T>(JsonStringToDeserialize);
        //return JsonConvert.DeserializeObject<T>(JsonStringToDeserialize, jsonSettings);
    }
}


/// <summary>
/// XmlHelper Functions
/// </summary>
public static class XmlHelper
{
    public static string EscapeEscapeChar(string xmlString)
    {
        if (string.IsNullOrEmpty(xmlString)) return xmlString;
        return xmlString.Replace("\\\"", "\"");
    }
    public static string EscapeXML(string nonXmlString)
    {
        if (string.IsNullOrEmpty(nonXmlString)) return nonXmlString;
        return nonXmlString.Replace("'", "&apos;").Replace("\"", "&quot;").Replace(">", "&gt;").Replace("<", "&lt;").Replace("&", "&amp;");
    }
    public static string UnescapeXML(string xmlString)
    {
        if (string.IsNullOrEmpty(xmlString)) return xmlString;
        return xmlString.Replace("&apos;", "'").Replace("&quot;", "\"").Replace("&gt;", ">").Replace("&lt;", "<").Replace("&amp;", "&");
    }
    public static string SerializeXMLObject<T>(this T xmlObjectToSerialize)
    {
        XmlSerializer xmlSerializer = new XmlSerializer(xmlObjectToSerialize.GetType());
        using (StringWriter textWriter = new StringWriter())
        {
            xmlSerializer.Serialize(textWriter, xmlObjectToSerialize);
            return textWriter.ToString();
        }
    }
    public static T DeserializeXMLObject<T>(this string xmlStringToDeserialize)
    {
        XmlSerializer xmlSerializer = new XmlSerializer(typeof(T));
        using (TextReader reader = new StringReader(xmlStringToDeserialize))
        {
            return (T)xmlSerializer.Deserialize(reader);
        }
    }
}
