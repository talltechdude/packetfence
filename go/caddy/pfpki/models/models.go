package models

import (
	"net"
	"time"

	"bytes"
	"crypto/dsa"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"math/big"
	"strconv"
	"strings"

	"github.com/inverse-inc/scep/scep"
	"github.com/knq/pemutil"

	"context"
	"fmt"
	"html/template"
	"io"
	"io/ioutil"

	"github.com/inverse-inc/packetfence/go/caddy/pfpki/certutils"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/cloud"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/sql"
	"github.com/inverse-inc/packetfence/go/caddy/pfpki/types"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	pkcs12 "software.sslmate.com/src/go-pkcs12"

	"github.com/inverse-inc/packetfence/go/pfconfigdriver"
	"golang.org/x/crypto/ocsp"
	"golang.org/x/text/language"
	"golang.org/x/text/message"
	"golang.org/x/text/message/catalog"
	gomail "gopkg.in/gomail.v2"
	yaml "gopkg.in/yaml.v2"
)

type (
	// CA struct
	CA struct {
		gorm.Model
		DB                   gorm.DB                 `gorm:"-"`
		Ctx                  context.Context         `gorm:"-"`
		Cn                   string                  `json:"cn,omitempty" gorm:"UNIQUE"`
		Mail                 string                  `json:"mail,omitempty" gorm:"INDEX:mail"`
		Organisation         string                  `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit   string                  `json:"organisational_unit,omitempty"`
		Country              string                  `json:"country,omitempty"`
		State                string                  `json:"state,omitempty"`
		Locality             string                  `json:"locality,omitempty"`
		StreetAddress        string                  `json:"street_address,omitempty"`
		PostalCode           string                  `json:"postal_code,omitempty"`
		KeyType              *types.Type             `json:"key_type,omitempty,string"`
		KeySize              int                     `json:"key_size,omitempty,string"`
		Digest               x509.SignatureAlgorithm `json:"digest,omitempty,string"`
		KeyUsage             *string                 `json:"key_usage,omitempty"`
		ExtendedKeyUsage     *string                 `json:"extended_key_usage,omitempty"`
		Days                 int                     `json:"days,omitempty,string"`
		Key                  string                  `json:"-" gorm:"type:longtext"`
		Cert                 string                  `json:"cert,omitempty" gorm:"type:longtext"`
		IssuerKeyHash        string                  `json:"issuer_key_hash,omitempty" gorm:"UNIQUE_INDEX"`
		IssuerNameHash       string                  `json:"issuer_name_hash,omitempty" gorm:"UNIQUE_INDEX"`
		OCSPUrl              string                  `json:"ocsp_url,omitempty"`
		SCEPAssociateProfile string                  `gorm:"-"`
		Cloud                cloud.Cloud             `gorm:"-"`
	}

	// Profile struct
	Profile struct {
		gorm.Model
		DB                    gorm.DB                 `gorm:"-"`
		Ctx                   context.Context         `gorm:"-"`
		Name                  string                  `json:"name" gorm:"UNIQUE"`
		Mail                  string                  `json:"mail,omitempty" gorm:"INDEX:mail"`
		Organisation          string                  `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit    string                  `json:"organisational_unit,omitempty"`
		Country               string                  `json:"country,omitempty"`
		State                 string                  `json:"state,omitempty"`
		Locality              string                  `json:"locality,omitempty"`
		StreetAddress         string                  `json:"street_address,omitempty"`
		PostalCode            string                  `json:"postal_code,omitempty"`
		Ca                    CA                      `json:"-"`
		CaID                  uint                    `json:"ca_id,omitempty,string" gorm:"INDEX:ca_id"`
		CaName                string                  `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		Validity              int                     `json:"validity,omitempty,string"`
		KeyType               *types.Type             `json:"key_type,omitempty,string"`
		KeySize               int                     `json:"key_size,omitempty,string"`
		Digest                x509.SignatureAlgorithm `json:"digest,omitempty,string"`
		KeyUsage              *string                 `json:"key_usage,omitempty"`
		ExtendedKeyUsage      *string                 `json:"extended_key_usage,omitempty"`
		OCSPUrl               string                  `json:"ocsp_url,omitempty"`
		P12MailPassword       int                     `json:"p12_mail_password,omitempty,string"`
		P12MailSubject        string                  `json:"p12_mail_subject,omitempty"`
		P12MailFrom           string                  `json:"p12_mail_from,omitempty"`
		P12MailHeader         string                  `json:"p12_mail_header,omitempty"`
		P12MailFooter         string                  `json:"p12_mail_footer,omitempty"`
		SCEPEnabled           int                     `json:"scep_enabled,omitempty,string"`
		SCEPChallengePassword string                  `json:"scep_challenge_password,omitempty"`
		SCEPDaysBeforeRenewal int                     `json:"scep_days_before_renewal,omitempty,string"`
		CloudEnabled          int                     `json:"cloud_enabled,omitempty,string"`
		CloudService          string                  `json:"cloud_service,omitempty"`
	}

	// Cert struct
	Cert struct {
		gorm.Model
		DB                 gorm.DB         `gorm:"-"`
		Ctx                context.Context `gorm:"-"`
		Cn                 string          `json:"cn,omitempty" gorm:"UNIQUE"`
		Mail               string          `json:"mail,omitempty" gorm:"INDEX:mail"`
		Ca                 CA              `json:"-"`
		CaID               uint            `json:"ca_id,omitempty" gorm:"INDEX:ca_id"`
		CaName             string          `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		StreetAddress      string          `json:"street_address,omitempty"`
		Organisation       string          `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit string          `json:"organisational_unit,omitempty"`
		Country            string          `json:"country,omitempty"`
		State              string          `json:"state,omitempty"`
		Locality           string          `json:"locality,omitempty"`
		PostalCode         string          `json:"postal_code,omitempty"`
		Key                string          `json:"-" gorm:"type:longtext"`
		Cert               string          `json:"cert,omitempty" gorm:"type:longtext"`
		Profile            Profile         `json:"-"`
		ProfileID          uint            `json:"profile_id,omitempty,string" gorm:"INDEX:profile_id"`
		ProfileName        string          `json:"profile_name,omitempty" gorm:"INDEX:profile_name"`
		ValidUntil         time.Time       `json:"valid_until,omitempty" gorm:"INDEX:valid_until"`
		Date               time.Time       `json:"date,omitempty" gorm:"default:CURRENT_TIMESTAMP"`
		SerialNumber       string          `json:"serial_number,omitempty"`
		DNSNames           string          `json:"dns_names,omitempty"`
		IPAddresses        string          `json:"ip_addresses,omitempty"`
		Scep               bool            `json:"scep,omitempty" gorm:"default:false"`
	}

	// RevokedCert struct
	RevokedCert struct {
		gorm.Model
		DB                 gorm.DB         `gorm:"-"`
		Ctx                context.Context `gorm:"-"`
		Cn                 string          `json:"cn,omitempty" gorm:"INDEX:cn"`
		Mail               string          `json:"mail,omitempty" gorm:"INDEX:mail"`
		Ca                 CA              `json:"-"`
		CaID               uint            `json:"ca_id,omitempty" gorm:"INDEX:ca_id"`
		CaName             string          `json:"ca_name,omitempty" gorm:"INDEX:ca_name"`
		StreetAddress      string          `json:"street_address,omitempty"`
		Organisation       string          `json:"organisation,omitempty" gorm:"INDEX:organisation"`
		OrganisationalUnit string          `json:"organisational_unit,omitempty"`
		Country            string          `json:"country,omitempty"`
		State              string          `json:"state,omitempty"`
		Locality           string          `json:"locality,omitempty"`
		PostalCode         string          `json:"postal_code,omitempty"`
		Key                string          `json:"-" gorm:"type:longtext"`
		Cert               string          `json:"cert,omitempty" gorm:"type:longtext"`
		Profile            Profile         `json:"-"`
		ProfileID          uint            `json:"profile_id,omitempty" gorm:"INDEX:profile_id"`
		ProfileName        string          `json:"profile_name,omitempty" gorm:"INDEX:profile_name"`
		ValidUntil         time.Time       `json:"valid_until,omitempty" gorm:"INDEX:valid_until"`
		Date               time.Time       `json:"date,omitempty" gorm:"default:CURRENT_TIMESTAMP"`
		SerialNumber       string          `json:"serial_number,omitempty"`
		DNSNames           string          `json:"dns_names,omitempty"`
		IPAddresses        string          `json:"ip_addresses,omitempty"`
		Revoked            time.Time       `json:"revoked,omitempty" gorm:"INDEX:revoked"`
		CRLReason          int             `json:"crl_reason,omitempty" gorm:"INDEX:crl_reason"`
	}
)

// Digest Values:
// 0 UnknownSignatureAlgorithm
// 1 MD2WithRSA
// 2 MD5WithRSA
// 3 SHA1WithRSA
// 4 SHA256WithRSA
// 5 SHA384WithRSA
// 6 SHA512WithRSA
// 7 DSAWithSHA1
// 8 DSAWithSHA256
// 9 ECDSAWithSHA1
// 10 ECDSAWithSHA256
// 11 ECDSAWithSHA384
// 12 ECDSAWithSHA512
// 13 SHA256WithRSAPSS
// 14 SHA384WithRSAPSS
// 15 SHA512WithRSAPSS
// 16 PureEd25519

// KeyUsage Values:
// 1 KeyUsageDigitalSignature
// 2 KeyUsageContentCommitment
// 4 KeyUsageKeyEncipherment
// 8 KeyUsageDataEncipherment
// 16 KeyUsageKeyAgreement
// 32 KeyUsageCertSign
// 64 KeyUsageCRLSign
// 128 KeyUsageEncipherOnly
// 256 KeyUsageDecipherOnly

// ExtendedKeyUsage Values:
// 0 ExtKeyUsageAny
// 1 ExtKeyUsageServerAuth
// 2 ExtKeyUsageClientAuth
// 3 ExtKeyUsageCodeSigning
// 4 ExtKeyUsageEmailProtection
// 5 ExtKeyUsageIPSECEndSystem
// 6 ExtKeyUsageIPSECTunnel
// 7 ExtKeyUsageIPSECUser
// 8 ExtKeyUsageTimeStamping
// 9 ExtKeyUsageOCSPSigning
// 10 ExtKeyUsageMicrosoftServerGatedCrypto
// 11 ExtKeyUsageNetscapeServerGatedCrypto
// 12 ExtKeyUsageMicrosoftCommercialCodeSigning
// 13 ExtKeyUsageMicrosoftKernelCodeSigning

var successDBConnect = false

// NewCAModel create a CAModel
func NewCAModel(pfpki *types.Handler) *CA {
	CA := &CA{}

	CA.DB = *pfpki.DB
	CA.Ctx = *pfpki.Ctx

	return CA
}

// New create a new CA
func (c CA) New() (types.Info, error) {

	Information := types.Info{}

	keyOut, pub, key, err := certutils.GenerateKey(*c.KeyType, c.KeySize)

	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	skid, err := certutils.CalculateSKID(pub)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var cadb CA
	var newcadb []CA

	var SerialNumber *big.Int

	if CaDB := c.DB.Last(&cadb); CaDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(cadb.ID + 1))
	}

	var Subject pkix.Name
	Subject.CommonName = c.Cn

	if len(c.Organisation) > 0 {
		Subject.Organization = []string{c.Organisation}
	}

	if len(c.OrganisationalUnit) > 0 {
		Subject.OrganizationalUnit = []string{c.OrganisationalUnit}
	}

	if len(c.Country) > 0 {
		Subject.Country = []string{c.Country}
	}

	if len(c.State) > 0 {
		Subject.Province = []string{c.State}
	}

	if len(c.Locality) > 0 {
		Subject.Locality = []string{c.Locality}
	}

	if len(c.StreetAddress) > 0 {
		Subject.StreetAddress = []string{c.StreetAddress}
	}

	if len(c.PostalCode) > 0 {
		Subject.PostalCode = []string{c.PostalCode}
	}

	ca := &x509.Certificate{
		SerialNumber:          SerialNumber,
		Subject:               Subject,
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(0, 0, c.Days),
		IsCA:                  true,
		SignatureAlgorithm:    c.Digest,
		ExtKeyUsage:           certutils.Extkeyusage(strings.Split(*c.ExtendedKeyUsage, "|")),
		KeyUsage:              x509.KeyUsage(certutils.Keyusage(strings.Split(*c.KeyUsage, "|"))),
		BasicConstraintsValid: true,
		EmailAddresses:        []string{c.Mail},
		SubjectKeyId:          skid,
		AuthorityKeyId:        skid,
	}

	if len(c.OCSPUrl) > 0 {
		ca.OCSPServer = []string{c.OCSPUrl}
	}

	var caBytes []byte

	switch *c.KeyType {
	case certutils.KEY_RSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*rsa.PrivateKey))
	case certutils.KEY_ECDSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*ecdsa.PrivateKey))
	case certutils.KEY_DSA:
		caBytes, err = x509.CreateCertificate(rand.Reader, ca, ca, pub, key.(*dsa.PrivateKey))
	}
	if err != nil {
		return Information, err
	}

	cert := new(bytes.Buffer)

	// Public key
	pem.Encode(cert, &pem.Block{Type: "CERTIFICATE", Bytes: caBytes})

	// Calculate the IssuerNameHash
	catls, err := tls.X509KeyPair([]byte(cert.String()), []byte(keyOut.String()))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	h := sha1.New()

	h.Write(cacert.RawIssuer)

	if err := c.DB.Create(&CA{Cn: c.Cn, Mail: c.Mail, Organisation: c.Organisation, OrganisationalUnit: c.OrganisationalUnit, Country: c.Country, State: c.State, Locality: c.Locality, StreetAddress: c.StreetAddress, PostalCode: c.PostalCode, KeyType: c.KeyType, KeySize: c.KeySize, Digest: c.Digest, KeyUsage: c.KeyUsage, ExtendedKeyUsage: c.ExtendedKeyUsage, Days: c.Days, Key: keyOut.String(), Cert: cert.String(), IssuerKeyHash: hex.EncodeToString(skid), IssuerNameHash: hex.EncodeToString(h.Sum(nil)), OCSPUrl: c.OCSPUrl}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	c.DB.Select("id, cn, mail, organisation, organisational_unit, country, state, locality, street_address, postal_code, key_type, key_size, digest, key_usage, extended_key_usage, days, cert, ocsp_url").Where("cn = ?", c.Cn).First(&newcadb)
	Information.Entries = newcadb

	return Information, nil
}

// GetByID retreive the CA by id
func (c CA) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var cadb []CA
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(c)[:], ",")
		c.DB.Select(allFields).Where("`id` = ?", val).First(&cadb)
	}
	Information.Entries = cadb

	return Information, nil
}

// Fix calculate the IssuerKeyHash and IssuerNameHash
func (c CA) Fix() (types.Info, error) {
	Information := types.Info{}
	var cadb []CA

	c.DB.Find(&cadb)
	for _, v := range cadb {
		if v.IssuerNameHash == "" {

			// Calculate the IssuerNameHash
			catls, err := tls.X509KeyPair([]byte(v.Cert), []byte(v.Key))
			if err != nil {
				Information.Error = err.Error()
				return Information, err
			}
			cacert, err := x509.ParseCertificate(catls.Certificate[0])
			if err != nil {
				Information.Error = err.Error()
				return Information, err
			}
			h := sha1.New()

			h.Write(cacert.RawIssuer)
			// var store pemutil.Store
			store := make(map[pemutil.BlockType]interface{})

			pemutil.Decode(store, []byte(v.Cert))
			var skid []byte
			for _, pemUtil := range store {
				cert := pemUtil.(*x509.Certificate)
				skid, _ = certutils.CalculateSKID(cert.PublicKey)
			}

			v.IssuerKeyHash = hex.EncodeToString(skid)
			v.IssuerNameHash = hex.EncodeToString(h.Sum(nil))
			c.DB.Save(&v)
		}
	}

	return Information, nil
}

// Paginated return the CA list paginated
func (c CA) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	c.DB.Model(&CA{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
		var cadb []CA
		c.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&cadb)
		Information.Entries = cadb
	}

	return Information, nil
}

// Search for the CA
func (c CA) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	var count int
	c.DB.Model(&CA{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var cadb []CA
		c.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&cadb)
		Information.Entries = cadb
	}

	return Information, nil
}

// FindSCEPProfile search the SCEP Profile by the profile name
func (c *CA) FindSCEPProfile(options []string) ([]Profile, error) {
	var profiledb []Profile
	if len(options) >= 1 {
		if err := c.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer, scep_enabled, scep_challenge_password, scep_days_before_renewal, cloud_enabled, cloud_service").Where("`name` = ?", options[0]).First(&profiledb).Error; err != nil {
			return profiledb, errors.New("A database error occured. See log for details.")
		}
		if len(profiledb) == 0 {
			return profiledb, errors.New("Unknow profile.")
		}

	} else {
		c.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer, scep_enabled, scep_challenge_password, scep_days_before_renewal, cloud_enabled, cloud_service").Where("`scep_enabled` = ?", "1").First(&profiledb)
	}
	c.SCEPAssociateProfile = profiledb[0].Name

	return profiledb, nil

}

// CA return the CA public key based on the profile name (SCEP)
func (c CA) CA(pass []byte, options ...string) ([]*x509.Certificate, *rsa.PrivateKey, error) {

	var profiledb []Profile

	profiledb, err := c.FindSCEPProfile(options)

	if err != nil {
		return nil, nil, err
	}

	var ca CA

	if CaDB := c.DB.First(&ca, profiledb[0].CaID).Find(&ca); CaDB.Error != nil {
		c.DB.First(&ca)
	}

	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	key, err := certutils.LoadKey([]byte(ca.Key), pass)
	return []*x509.Certificate{cacert}, key, err
}

// Put create the public key in the DB (SCEP)
func (c CA) Put(cn string, crt *x509.Certificate, options ...string) error {

	attributeMap := certutils.GetDNFromCert(crt.Subject)

	publicKey := new(bytes.Buffer)

	pem.Encode(publicKey, &pem.Block{Type: "CERTIFICATE", Bytes: crt.Raw})

	profiledb, err := c.FindSCEPProfile(options)

	if err != nil {
		return err
	}

	var ca CA

	if CaDB := c.DB.First(&ca, profiledb[0].CaID).Find(&ca); CaDB.Error != nil {
		c.DB.First(&ca)
	}

	if err := c.DB.Create(&Cert{Cn: cn, Ca: ca, CaName: ca.Cn, ProfileName: profiledb[0].Name, SerialNumber: crt.SerialNumber.String(), Mail: attributeMap["emailAddress"], StreetAddress: attributeMap["streetAddress"], Organisation: attributeMap["O"], OrganisationalUnit: attributeMap["OU"], Country: attributeMap["C"], State: attributeMap["ST"], Locality: attributeMap["L"], PostalCode: attributeMap["emailAddress"], Profile: profiledb[0], Key: "", Cert: publicKey.String(), ValidUntil: crt.NotAfter, Scep: true}).Error; err != nil {
		return errors.New("A database error occured. See log for details.")
	}

	return nil
}

// Serial return the serial number
func (c CA) Serial(options ...string) (*big.Int, error) {

	profiledb, err := c.FindSCEPProfile(options)

	if err != nil {
		return nil, err
	}

	var ca CA

	if CaDB := c.DB.First(&ca, profiledb[0].CaID).Find(&ca); CaDB.Error != nil {
		c.DB.First(&ca)
	}

	var certdb Cert

	var SerialNumber *big.Int

	if CertDB := c.DB.Last(&certdb).Related(&ca); CertDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(certdb.ID + 1))
	}

	return SerialNumber, nil
}

func (c CA) HasCN(cn string, allowTime int, cert *x509.Certificate, revokeOldCertificate bool, options ...string) (bool, error) {

	var certif Cert
	var CertDB *gorm.DB
	if CertDB = c.DB.Where("Cn = ?", cn).Find(&certif); CertDB.Error != nil {
		// There is no certificate with this CN in the DB
		return true, nil
	}

	if CertDB.RowsAffected == 0 {
		return true, nil
	}

	certif.DB = c.DB
	certif.Ctx = c.Ctx

	store := make(map[pemutil.BlockType]interface{})

	pemutil.Decode(store, []byte(certif.Cert))
	for _, pemUtil := range store {
		cert := pemUtil.(*x509.Certificate)

		if cert.NotAfter.Unix()-int64((14*24*time.Hour).Seconds()) < time.Now().Unix() {

			params := make(map[string]string)

			params["id"] = strconv.Itoa(int(certif.ID))
			params["reason"] = strconv.Itoa(ocsp.Superseded)
			certif.Revoke(params)
			return true, nil
		}
	}
	return false, errors.New("Certificate with this CN already exist")
}

// SCEP Verify
func (c CA) Verify(m *scep.CSRReqMessage) (bool, error) {
	prof, _ := c.GetProfileByName(c.SCEPAssociateProfile)

	if prof.CloudEnabled == 1 {
		vcloud, err := cloud.Create(c.Ctx, "intune", prof.CloudService)
		if err != nil {
			return false, err
		}
		err = vcloud.ValidateRequest(c.Ctx, m.CSR.Raw)
		if err != nil {
			return false, err
		}
		c.Cloud = vcloud
		// vcloud.SuccessReply(c.Ctx, m.CSR.Raw, "Siwuper !")
		return true, nil
	}
	return true, nil
}

func (c CA) FailureNotify(cert *x509.Certificate, m *scep.CSRReqMessage, message string) {
	if c.Cloud != nil {
		c.Cloud.FailureReply(c.Ctx, cert, m.CSR.Raw, message)
	}
}

func (c CA) SuccessNotify(cert *x509.Certificate, m *scep.CSRReqMessage, message string) {
	if c.Cloud != nil {
		c.Cloud.SuccessReply(c.Ctx, cert, m.CSR.Raw, message)
	}
}

func (c CA) GetProfileByName(name string) (*Profile, error) {
	var profiledb []Profile
	c.DB.Select("id, name, ca_id, ca_name, mail, street_address, organisation, organisational_unit, country, state, locality, postal_code, validity, key_type, key_size, digest, key_usage, extended_key_usage, ocsp_url, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer, scep_enabled, scep_challenge_password, scep_days_before_renewal, cloud_enabled, cloud_service").Where("name = ?", name).First(&profiledb)

	return &profiledb[0], nil
}

func NewProfileModel(pfpki *types.Handler) *Profile {
	Profile := &Profile{}

	Profile.DB = *pfpki.DB
	Profile.Ctx = *pfpki.Ctx

	return Profile
}

func (p Profile) New() (types.Info, error) {

	var profiledb []Profile

	var err error
	Information := types.Info{}
	switch *p.KeyType {
	case certutils.KEY_RSA:
		if p.KeySize < 2048 {
			err = errors.New("invalid private key size, should be at least 2048")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_ECDSA:
		if !(p.KeySize == 256 || p.KeySize == 384 || p.KeySize == 521) {
			err = errors.New("invalid private key size, should be 256 or 384 or 521")
			Information.Error = err.Error()
			return Information, err
		}
	case certutils.KEY_DSA:
		if !(p.KeySize == 1024 || p.KeySize == 2048 || p.KeySize == 3072) {
			err = errors.New("invalid private key size, should be 1024 or 2048 or 3072")
			Information.Error = err.Error()
			return Information, err
		}
	default:
		return Information, errors.New("KeyType unsupported")

	}

	ca := &CA{}

	if CaDB := p.DB.First(&ca, p.CaID).Find(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, CaDB.Error
	}

	if err := p.DB.Create(&Profile{Name: p.Name, Ca: *ca, CaID: p.CaID, CaName: ca.Cn, Mail: p.Mail, StreetAddress: p.StreetAddress, Organisation: p.Organisation, OrganisationalUnit: p.OrganisationalUnit, Country: p.Country, State: p.State, Locality: p.Locality, PostalCode: p.PostalCode, Validity: p.Validity, KeyType: p.KeyType, KeySize: p.KeySize, Digest: p.Digest, KeyUsage: p.KeyUsage, ExtendedKeyUsage: p.ExtendedKeyUsage, OCSPUrl: p.OCSPUrl, P12MailPassword: p.P12MailPassword, P12MailSubject: p.P12MailSubject, P12MailFrom: p.P12MailFrom, P12MailHeader: p.P12MailHeader, P12MailFooter: p.P12MailFooter, SCEPEnabled: p.SCEPEnabled, SCEPChallengePassword: p.SCEPChallengePassword, SCEPDaysBeforeRenewal: p.SCEPDaysBeforeRenewal, CloudEnabled: p.CloudEnabled, CloudService: p.CloudService}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	p.DB.Select("id, name, ca_id, ca_name, mail, street_address, organisation, organisational_unit, country, state, locality, postal_code, validity, key_type, key_size, digest, key_usage, extended_key_usage, ocsp_url, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer, scep_enabled, scep_challenge_password, scep_days_before_renewal, cloud_enabled, cloud_service").Where("name = ?", p.Name).First(&profiledb)
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) Update() (types.Info, error) {
	var profiledb []Profile
	Information := types.Info{}
	if err := p.DB.Model(&Profile{}).Where("name = ?", p.Name).Updates(map[string]interface{}{"p12_mail_password": p.P12MailPassword, "p12_mail_subject": p.P12MailSubject, "p12_mail_from": p.P12MailFrom, "p12_mail_header": p.P12MailHeader, "p12_mail_footer": p.P12MailFooter, "scep_enabled": p.SCEPEnabled, "scep_challenge_password": p.SCEPChallengePassword, "scep_days_before_renewal": p.SCEPDaysBeforeRenewal, "cloud_enabled": p.CloudEnabled, "cloud_service": p.CloudService}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	p.DB.Select("id, name, ca_id, ca_name, validity, key_type, key_size, digest, key_usage, extended_key_usage, ocsp_url, p12_mail_password, p12_mail_subject, p12_mail_from, p12_mail_header, p12_mail_footer, scep_enabled, scep_challenge_password, scep_days_before_renewal, cloud_enabled, cloud_service").Where("name = ?", p.Name).First(&profiledb)
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var profiledb []Profile
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(p)[:], ",")
		p.DB.Select(allFields).Where("`id` = ?", val).First(&profiledb)
	}
	Information.Entries = profiledb

	return Information, nil
}

func (p Profile) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	p.DB.Model(&Profile{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(p)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
		var profiledb []Profile
		p.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&profiledb)
		Information.Entries = profiledb
	}

	return Information, nil
}

func (p Profile) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(p)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	var count int
	p.DB.Model(&Profile{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var profiledb []Profile
		p.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&profiledb)
		Information.Entries = profiledb
	}

	return Information, nil
}

func NewCertModel(pfpki *types.Handler) *Cert {
	Cert := &Cert{}

	Cert.DB = *pfpki.DB
	Cert.Ctx = *pfpki.Ctx

	return Cert
}

func (c Cert) New() (types.Info, error) {
	Information := types.Info{}

	// Find the profile
	var prof Profile
	if profDB := c.DB.First(&prof, c.ProfileID); profDB.Error != nil {
		Information.Error = profDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	// Find the CA
	var ca CA
	if CaDB := c.DB.First(&ca, prof.CaID).Find(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var certdb Cert
	var newcertdb []Cert
	var SerialNumber *big.Int

	if CertDB := c.DB.Last(&certdb).Related(&ca); CertDB.Error != nil {
		SerialNumber = big.NewInt(1)
	} else {
		SerialNumber = big.NewInt(int64(certdb.ID + 1))
	}

	keyOut, pub, _, err := certutils.GenerateKey(*prof.KeyType, prof.KeySize)

	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	skid, err := certutils.CalculateSKID(pub)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	var Subject pkix.Name
	Subject.CommonName = c.Cn

	Organization := ""
	if len(prof.Organisation) > 0 {
		Organization = prof.Organisation
	}
	if len(c.Organisation) > 0 {
		Organization = c.Organisation
	}
	if len(Organization) > 0 {
		Subject.Organization = []string{Organization}
	}

	OrganizationalUnit := ""
	if len(prof.OrganisationalUnit) > 0 {
		OrganizationalUnit = prof.OrganisationalUnit
	}
	if len(c.OrganisationalUnit) > 0 {
		OrganizationalUnit = c.OrganisationalUnit
	}
	if len(OrganizationalUnit) > 0 {
		Subject.OrganizationalUnit = []string{OrganizationalUnit}
	}

	Country := ""
	if len(prof.Country) > 0 {
		Country = prof.Country
	}
	if len(c.Country) > 0 {
		Country = c.Country
	}
	if len(Country) > 0 {
		Subject.Country = []string{Country}
	}

	Province := ""
	if len(prof.State) > 0 {
		Province = prof.State
	}
	if len(c.State) > 0 {
		Province = c.State
	}
	if len(Province) > 0 {
		Subject.Province = []string{Province}
	}

	Locality := ""
	if len(prof.Locality) > 0 {
		Locality = prof.Locality
	}
	if len(c.Locality) > 0 {
		Locality = c.Locality
	}
	if len(Locality) > 0 {
		Subject.Locality = []string{Locality}
	}

	StreetAddress := ""
	if len(prof.StreetAddress) > 0 {
		StreetAddress = prof.StreetAddress
	}
	if len(c.StreetAddress) > 0 {
		StreetAddress = c.StreetAddress
	}
	if len(StreetAddress) > 0 {
		Subject.StreetAddress = []string{StreetAddress}
	}

	PostalCode := ""
	if len(prof.PostalCode) > 0 {
		PostalCode = prof.PostalCode
	}
	if len(c.PostalCode) > 0 {
		PostalCode = c.PostalCode
	}
	if len(PostalCode) > 0 {
		Subject.PostalCode = []string{PostalCode}
	}

	// Prepare certificate
	cert := &x509.Certificate{
		SerialNumber: SerialNumber,
		Subject:      Subject,
		NotBefore:    time.Now(),
		NotAfter:     time.Now().AddDate(0, 0, prof.Validity),
		ExtKeyUsage:  certutils.Extkeyusage(strings.Split(*prof.ExtendedKeyUsage, "|")),
		KeyUsage:     x509.KeyUsage(certutils.Keyusage(strings.Split(*prof.KeyUsage, "|"))),
		SubjectKeyId: skid,
	}

	if len(prof.OCSPUrl) > 0 {
		cert.OCSPServer = []string{prof.OCSPUrl}
	}
	if len(c.Mail) > 0 {
		for _, mail := range strings.Split(c.Mail, ",") {
			cert.EmailAddresses = append(cert.EmailAddresses, mail)
		}
	}

	if len(c.DNSNames) > 0 {
		for _, dns := range strings.Split(c.DNSNames, ",") {
			cert.DNSNames = append(cert.DNSNames, dns)
		}
	}

	if len(c.IPAddresses) > 0 {
		for _, ip := range strings.Split(c.IPAddresses, ",") {
			cert.IPAddresses = append(cert.IPAddresses, net.ParseIP(ip))
		}
	}

	// Sign the certificate
	certByte, err := x509.CreateCertificate(rand.Reader, cert, cacert, pub, catls.PrivateKey)

	certBuff := new(bytes.Buffer)

	// Public key
	pem.Encode(certBuff, &pem.Block{Type: "CERTIFICATE", Bytes: certByte})

	if err := c.DB.Create(&Cert{Cn: c.Cn, Ca: ca, CaName: ca.Cn, ProfileName: prof.Name, SerialNumber: SerialNumber.String(), DNSNames: c.DNSNames, IPAddresses: c.IPAddresses, Mail: c.Mail, StreetAddress: StreetAddress, Organisation: Organization, OrganisationalUnit: OrganizationalUnit, Country: Country, State: Province, Locality: Locality, PostalCode: PostalCode, Profile: prof, Key: keyOut.String(), Cert: certBuff.String(), ValidUntil: cert.NotAfter}).Error; err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	c.DB.Select("id, cn, mail, street_address, organisation, organisational_unit, country, state, locality, postal_code, cert, profile_id, profile_name, ca_name, ca_id, valid_until, serial_number, dns_names, ip_addresses").Where("cn = ?", c.Cn).First(&newcertdb)
	Information.Entries = newcertdb

	return Information, nil
}

func (c Cert) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var certdb []Cert
	allFields := strings.Join(sql.SqlFields(c)[:], ",")
	if val, ok := params["id"]; ok {
		c.DB.Select(allFields).Where("`id` = ?", val).First(&certdb)
	}
	if val, ok := params["cn"]; ok {
		c.DB.Select(allFields).Where("`cn` = ?", val).First(&certdb)
	}

	Information.Entries = certdb

	return Information, nil
}

func (c Cert) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	c.DB.Model(&Cert{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
		var certdb []Cert
		c.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&certdb)
		Information.Entries = certdb
	}

	return Information, nil
}

func (c Cert) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}
	var count int
	c.DB.Model(&Cert{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var certdb []Cert
		c.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&certdb)
		Information.Entries = certdb
	}

	return Information, nil
}

func (c Cert) Download(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	// Find the Cert
	var cert Cert
	if val, ok := params["cn"]; ok {
		if CertDB := c.DB.Where("Cn = ?", val).Find(&cert); CertDB.Error != nil {
			Information.Error = CertDB.Error.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
	}
	if val, ok := params["id"]; ok {
		if CertDB := c.DB.First(&cert, val); CertDB.Error != nil {
			Information.Error = CertDB.Error.Error()
			return Information, errors.New("A database error occured. See log for details.")
		}
	}

	// Find the CA
	var ca CA
	if CaDB := c.DB.Model(&cert).Related(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	// Load the certificates from the database
	certtls, err := tls.X509KeyPair([]byte(cert.Cert), []byte(cert.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Find the profile
	var prof Profile
	if profDB := c.DB.Where("Name = ?", cert.ProfileName).Find(&prof); profDB.Error != nil {
		Information.Error = profDB.Error.Error()
		return Information, errors.New("A database error occured. See log for details.")
	}

	certificate, err := x509.ParseCertificate(certtls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	// Load the certificates from the database
	catls, err := tls.X509KeyPair([]byte(ca.Cert), []byte(ca.Key))
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cacert, err := x509.ParseCertificate(catls.Certificate[0])
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	var CaCert []*x509.Certificate

	CaCert = append(CaCert, cacert)

	var password string
	if val, ok := params["password"]; ok {
		password = val
	} else {
		password = certutils.GeneratePassword()
	}
	Information.Password = password

	pkcs12, err := pkcs12.Encode(certutils.PRNG, certtls.PrivateKey, certificate, CaCert, password)

	if _, ok := params["password"]; ok {
		Information.Raw = pkcs12
		Information.ContentType = "application/x-pkcs12"
	} else {
		Information, err = email(c.Ctx, cert, prof, pkcs12, password)
	}

	return Information, err
}

func (c Cert) Revoke(params map[string]string) (types.Info, error) {

	Information := types.Info{}
	// Find the Cert
	var cert Cert

	id := params["id"]
	reason := params["reason"]

	if CertDB := c.DB.Where("id = ?", id).Find(&cert); CertDB.Error != nil {
		Information.Error = CertDB.Error.Error()
		return Information, CertDB.Error
	}

	// Find the CA
	var ca CA
	if CaDB := c.DB.Model(&cert).Related(&ca); CaDB.Error != nil {
		Information.Error = CaDB.Error.Error()
		return Information, CaDB.Error
	}

	// Find the Profile
	var profile Profile
	if ProfileDB := c.DB.Model(&cert).Related(&profile); ProfileDB.Error != nil {
		Information.Error = ProfileDB.Error.Error()
		return Information, ProfileDB.Error
	}

	intreason, err := strconv.Atoi(reason)
	if err != nil {
		Information.Error = "Reason unsupported"
		return Information, errors.New("Reason unsupported")
	}

	if err := c.DB.Create(&RevokedCert{Cn: cert.Cn, Mail: cert.Mail, Ca: ca, CaID: cert.CaID, CaName: cert.CaName, StreetAddress: cert.StreetAddress, Organisation: cert.Organisation, OrganisationalUnit: cert.OrganisationalUnit, Country: cert.Country, State: cert.State, Locality: cert.Locality, PostalCode: cert.Locality, Key: cert.Key, Cert: cert.Cert, Profile: profile, ProfileID: cert.ProfileID, ProfileName: cert.ProfileName, ValidUntil: cert.ValidUntil, Date: cert.Date, Revoked: time.Now(), CRLReason: intreason, SerialNumber: cert.SerialNumber, DNSNames: cert.DNSNames, IPAddresses: cert.IPAddresses}).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	if err := c.DB.Unscoped().Delete(&cert).Error; err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

func NewRevokedCertModel(pfpki *types.Handler) *RevokedCert {
	RevokedCert := &RevokedCert{}

	RevokedCert.DB = *pfpki.DB
	RevokedCert.Ctx = *pfpki.Ctx

	return RevokedCert
}

func (c RevokedCert) GetByID(params map[string]string) (types.Info, error) {
	Information := types.Info{}
	var revokedcertdb []RevokedCert
	if val, ok := params["id"]; ok {
		allFields := strings.Join(sql.SqlFields(c)[:], ",")
		c.DB.Select(allFields).Where("`id` = ?", val).First(&revokedcertdb)
	}
	Information.Entries = revokedcertdb

	return Information, nil
}

func (c RevokedCert) Paginated(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	var count int
	c.DB.Model(&Cert{}).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		sql, err := vars.Sql(c)
		if err != nil {
			Information.Error = err.Error()
			return Information, err
		}
		var revokedcertdb []RevokedCert
		c.DB.Select(sql.Select).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&revokedcertdb)
		Information.Entries = revokedcertdb
	}

	return Information, nil
}

func (c RevokedCert) Search(vars sql.Vars) (types.Info, error) {
	Information := types.Info{}
	sql, err := vars.Sql(c)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	var count int
	c.DB.Model(&Cert{}).Where(sql.Where.Query, sql.Where.Values...).Count(&count)
	Information.TotalCount = count
	Information.PrevCursor = vars.Cursor
	Information.NextCursor = vars.Cursor + vars.Limit
	if vars.Cursor < count {
		var revokedcertdb []RevokedCert
		c.DB.Select(sql.Select).Where(sql.Where.Query, sql.Where.Values...).Order(sql.Order).Offset(sql.Offset).Limit(sql.Limit).Find(&revokedcertdb)
		Information.Entries = revokedcertdb
	}

	return Information, nil
}

// EmailType strucure
type EmailType struct {
	Header   string
	Footer   string
	Password string
}

func email(ctx context.Context, cert Cert, profile Profile, file []byte, password string) (types.Info, error) {
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Alerting)
	pfconfigdriver.PfconfigPool.AddStruct(ctx, &pfconfigdriver.Config.PfConf.Advanced)
	alerting := pfconfigdriver.Config.PfConf.Alerting
	advanced := pfconfigdriver.Config.PfConf.Advanced

	Information := types.Info{}

	dict, err := ParseYAMLDict()
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	cat, err := catalog.NewFromMap(dict)
	if err != nil {
		Information.Error = err.Error()
		return Information, err
	}
	message.DefaultCatalog = cat

	m := gomail.NewMessage()
	m.SetHeader("From", alerting.FromAddr)
	m.SetHeader("To", cert.Mail)
	m.SetHeader("Subject", profile.P12MailSubject)

	email := EmailType{Header: profile.P12MailHeader, Footer: profile.P12MailFooter}

	// Undefined Header
	if profile.P12MailHeader == "" {
		email.Header = "msg_header"
	}
	// Undefined Footer
	if profile.P12MailHeader == "" {
		email.Footer = "msg_footer"
	}

	if profile.P12MailPassword == 1 {
		email.Password = password
		Information.Password = password
	}

	lang := language.MustParse(advanced.Language)

	emailContent, err := parseTemplate("emails-pki_certificate.html", lang, email)

	m.SetBody("text/html", emailContent)

	m.Attach(cert.Cn+".p12", gomail.SetCopyFunc(func(w io.Writer) error {
		_, err := w.Write(file)
		return err
	}))

	d := gomail.NewDialer(alerting.SMTPServer, alerting.SMTPPort, alerting.SMTPUsername, alerting.SMTPPassword)

	if alerting.SMTPVerifySSL == "disabled" {
		d.TLSConfig = &tls.Config{InsecureSkipVerify: true}
	}

	if err := d.DialAndSend(m); err != nil {
		Information.Error = err.Error()
		return Information, err
	}

	return Information, nil
}

func parseTemplate(tplName string, lang language.Tag, data interface{}) (string, error) {
	p := message.NewPrinter(lang)
	fmap := template.FuncMap{
		"translate": p.Sprintf,
	}

	t, err := template.New(tplName).Funcs(fmap).ParseFiles("/usr/local/pf/html/captive-portal/templates/emails/" + tplName)
	if err != nil {
		return "", fmt.Errorf("cannot parse template")
	}

	buf := bytes.NewBuffer([]byte{})
	if err := t.Execute(buf, data); err != nil {
		return "", fmt.Errorf("cannot execute parse template")
	}

	return buf.String(), nil
}

func ParseYAMLDict() (map[string]catalog.Dictionary, error) {
	dir := "/usr/local/pf/conf/caddy-services/locales"
	files, err := ioutil.ReadDir(dir)
	if err != nil {
		fmt.Println(err)
		return nil, err
	}

	translations := map[string]catalog.Dictionary{}

	for _, f := range files {
		yamlFile, err := ioutil.ReadFile(dir + "/" + f.Name())
		if err != nil {
			return nil, err
		}
		data := map[string]string{}
		err = yaml.Unmarshal(yamlFile, &data)
		if err != nil {
			return nil, err
		}

		lang := strings.Split(f.Name(), ".")[0]

		translations[lang] = &dictionary{Data: data}
	}

	return translations, nil
}

type dictionary struct {
	Data map[string]string
}

func (d *dictionary) Lookup(key string) (data string, ok bool) {
	if _, ok := d.Data[key]; !ok {
		return "", false
	}

	return "\x02" + d.Data[key], true
}
