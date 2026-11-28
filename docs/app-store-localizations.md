# Chữ trên App Store cho 6 ngôn ngữ

Soạn 2026-11-28 cho bản có tiếng Tây Ban Nha, Pháp, Đức, Bồ Đào Nha (Brazil), Nhật, Thái. Bản tiếng Anh gốc: [app-store-products.md](app-store-products.md) và brief mục tên app.

**Thứ tự dán trên App Store Connect:**
1. App Information → Localizable Information: thêm ngôn ngữ ở góc trên phải (Spanish (Mexico), Spanish (Spain), French, French (Canada), German, Portuguese (Brazil), Japanese, Thai), rồi dán Name và Subtitle.
2. Phiên bản → mỗi ngôn ngữ: Description, Keywords, Promotional Text, ảnh chụp (không bắt buộc, thiếu thì dùng ảnh tiếng Anh).
3. Mỗi IAP và nhóm đăng ký → Localization: Display Name và Description.

Tiếng Tây Ban Nha và Pháp có hai bản trên App Store (Mexico/Spain, France/Canada). Dán cùng một nội dung cho cả hai; app chỉ có một bản dịch `es` và một bản `fr`.

**Keywords** chỉ đổi được khi gửi phiên bản mới. Đây là bản đầu, chưa kiểm bằng search hints của từng nước. Apple ghép chữ từ Name, Subtitle và Keywords, nên Keywords không lặp chữ đã có ở hai ô kia. Viết liền, cách nhau bằng dấu phẩy, không dấu cách, tối đa 100 ký tự.

**Description:** chưa soạn vì repo chưa có bản tiếng Anh. Dán bản tiếng Anh đang dùng vào đây, mình dịch sang 6 ngôn ngữ. Đoạn điều khoản gói đăng ký ở cuối file phải nằm cuối Description của **mọi** ngôn ngữ (Guideline 3.1.2).

## Tên app và tên phụ

| | Name (≤ 30) | Subtitle (≤ 30) |
|---|---|---|
| en | Colorkin: Photo Coloring Book | Custom Kids Pages & Book Maker |
| es | Colorkin: Fotos para colorear | Libro personalizado para niños |
| fr | Colorkin : Coloriage photo | Pages et livres pour enfants |
| de | Colorkin: Foto-Malbuch | Ausmalbilder & Buch für Kinder |
| pt-BR | Colorkin: Fotos para colorir | Livro personalizado infantil |
| ja | Colorkin: 写真でぬりえ | 家族の写真から子どものぬりえ本 |
| th | Colorkin: ระบายสีจากรูปถ่าย | สร้างสมุดระบายสีให้ลูก |

## Keywords (≤ 100)

| | Keywords |
|---|---|
| es | dibujo,familia,mascota,imprimir,regalo,nombre,niño,bebé,contorno,boceto,caricatura,arte,pintar |
| fr | dessin,famille,animal,imprimer,cadeau,prénom,bébé,contour,croquis,art,peinture,crayon,personnalisé |
| de | Malvorlage,Familie,Haustier,drucken,Geschenk,Name,Baby,Umriss,Skizze,Zeichnung,Kunst,personalisiert |
| pt-BR | desenho,família,pet,imprimir,presente,nome,bebê,contorno,esboço,arte,pintar,giz,personalizado |
| ja | 塗り絵,子供,知育,プリント,似顔絵,イラスト,ペット,家族写真,プレゼント,名入れ,キッズ,お絵かき,線画 |
| th | ระบายสี,เด็ก,ครอบครัว,สัตว์เลี้ยง,พิมพ์,ของขวัญ,วาดรูป,ภาพลายเส้น,การ์ตูน,ชื่อ,ศิลปะ,สมุดภาพ |

## Promotional Text (≤ 170, sửa lúc nào cũng được)

| | Promotional Text |
|---|---|
| en | Turn family photos into coloring pages, then make a book with your child's name and print it at home. |
| es | Convierte tus fotos familiares en dibujos para colorear y crea un libro con el nombre de tu hijo para imprimir en casa. |
| fr | Transforme tes photos de famille en coloriages, puis crée un livre au prénom de ton enfant à imprimer à la maison. |
| de | Verwandle Familienfotos in Ausmalbilder und gestalte ein Malbuch mit dem Namen deines Kindes – zum Ausdrucken zu Hause. |
| pt-BR | Transforme fotos da família em desenhos para colorir e crie um livro com o nome do seu filho para imprimir em casa. |
| ja | 家族の写真がぬりえに。お子さまの名前入りのぬりえブックを作って、おうちで印刷できます。 |
| th | เปลี่ยนรูปครอบครัวเป็นภาพระบายสี แล้วทำสมุดที่มีชื่อลูก พิมพ์ได้ที่บ้าน |

## Nhóm đăng ký và IAP

Subscription Group Display Name: `Colorkin Pro` ở mọi ngôn ngữ.

Display Name tối đa 35 ký tự, Description tối đa 55. Tên gói đăng ký phải có chữ "tháng" hoặc "năm" (xem app-store-products.md).

| | Pro Monthly | Pro Yearly | Mô tả hai gói Pro |
|---|---|---|---|
| es | Colorkin Pro mensual | Colorkin Pro anual | 60 páginas con IA al mes y libros ilimitados |
| fr | Colorkin Pro mensuel | Colorkin Pro annuel | 60 pages IA par mois et livres illimités |
| de | Colorkin Pro monatlich | Colorkin Pro jährlich | 60 KI-Seiten im Monat, unbegrenzt Bücher |
| pt-BR | Colorkin Pro mensal | Colorkin Pro anual | 60 páginas de IA por mês e livros ilimitados |
| ja | Colorkin Pro 月額 | Colorkin Pro 年額 | 毎月AIぬりえ60枚、ブックは作り放題 |
| th | Colorkin Pro รายเดือน | Colorkin Pro รายปี | หน้า AI 60 หน้าต่อเดือน สร้างสมุดได้ไม่จำกัด |

| | One Coloring Book | Mô tả | Three Coloring Books | Mô tả |
|---|---|---|---|---|
| es | Un libro para colorear | Un libro de hasta 20 páginas, listo para imprimir | Tres libros para colorear | Tres libros de hasta 20 páginas cada uno |
| fr | Un livre de coloriage | Un livre de 20 pages max, prêt à imprimer | Trois livres de coloriage | Trois livres de 20 pages max chacun |
| de | Ein Malbuch | Ein Buch mit bis zu 20 Seiten, druckfertig | Drei Malbücher | Drei Bücher mit je bis zu 20 Seiten |
| pt-BR | Um livro de colorir | Um livro de até 20 páginas, pronto para imprimir | Três livros de colorir | Três livros de até 20 páginas cada |
| ja | ぬりえブック1冊 | 最大20ページのブック1冊、印刷できます | ぬりえブック3冊 | 最大20ページのブック3冊 |
| th | สมุดระบายสี 1 เล่ม | สมุด 1 เล่ม สูงสุด 20 หน้า พร้อมพิมพ์ | สมุดระบายสี 3 เล่ม | สมุด 3 เล่ม เล่มละสูงสุด 20 หน้า |

## Đoạn điều khoản cuối Description

Giá trong đoạn này là giá Mỹ; Apple hiện giá theo từng nước trên trang mua, nên giữ câu "Prices may vary by region".

**es**
```
CONDICIONES DE SUSCRIPCIÓN
Colorkin Pro mensual es una suscripción con renovación automática de USD 7.99 al mes. Colorkin Pro anual es una suscripción con renovación automática de USD 29.99 al año, con una prueba gratuita de 3 días para nuevos suscriptores. Ambos planes pueden compartirse con hasta 5 familiares mediante En familia. Los precios pueden variar según la región. El pago se carga a tu cuenta de Apple al confirmar la compra o al terminar la prueba gratuita. La suscripción se renueva automáticamente a menos que desactives la renovación automática al menos 24 horas antes del fin del período actual; la renovación se cobra dentro de las 24 horas previas a esa fecha. Puedes gestionarla o cancelarla en cualquier momento en los ajustes de tu cuenta de Apple.

Un libro para colorear es una compra única de USD 4.99 para un libro de hasta 20 páginas. Tres libros para colorear es una compra única de USD 9.99 para tres libros.

Política de privacidad: https://luongcongtoan.github.io/coloringbook/privacy.html
Condiciones de uso (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**fr**
```
CONDITIONS D'ABONNEMENT
Colorkin Pro mensuel est un abonnement à renouvellement automatique de 7,99 USD par mois. Colorkin Pro annuel est un abonnement à renouvellement automatique de 29,99 USD par an, avec un essai gratuit de 3 jours pour les nouveaux abonnés. Les deux formules peuvent être partagées avec jusqu'à 5 membres de la famille grâce au Partage familial. Les prix peuvent varier selon la région. Le paiement est débité de ton compte Apple lors de la confirmation de l'achat ou à la fin de l'essai gratuit. L'abonnement se renouvelle automatiquement sauf si le renouvellement automatique est désactivé au moins 24 heures avant la fin de la période en cours ; le renouvellement est facturé dans les 24 heures précédant cette date. Tu peux gérer ou résilier ton abonnement à tout moment dans les réglages de ton compte Apple.

Un livre de coloriage est un achat unique de 4,99 USD pour un livre de 20 pages maximum. Trois livres de coloriage est un achat unique de 9,99 USD pour trois livres.

Politique de confidentialité : https://luongcongtoan.github.io/coloringbook/privacy.html
Conditions d'utilisation (EULA) : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**de**
```
ABO-BEDINGUNGEN
Colorkin Pro monatlich ist ein automatisch verlängerbares Abo für 7,99 USD pro Monat. Colorkin Pro jährlich ist ein automatisch verlängerbares Abo für 29,99 USD pro Jahr, mit einem kostenlosen 3-Tage-Test für neue Abonnenten. Beide Abos können über die Familienfreigabe mit bis zu 5 Familienmitgliedern geteilt werden. Preise können je nach Region abweichen. Die Zahlung wird bei Bestätigung des Kaufs oder am Ende des kostenlosen Tests deinem Apple Account belastet. Das Abo verlängert sich automatisch, wenn die automatische Verlängerung nicht mindestens 24 Stunden vor Ende des aktuellen Zeitraums deaktiviert wird; die Verlängerung wird innerhalb von 24 Stunden vor diesem Datum berechnet. Du kannst dein Abo jederzeit in den Einstellungen deines Apple Accounts verwalten oder kündigen.

Ein Malbuch ist ein einmaliger Kauf für 4,99 USD für ein Buch mit bis zu 20 Seiten. Drei Malbücher ist ein einmaliger Kauf für 9,99 USD für drei Bücher.

Datenschutzerklärung: https://luongcongtoan.github.io/coloringbook/privacy.html
Nutzungsbedingungen (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**pt-BR**
```
TERMOS DE ASSINATURA
Colorkin Pro mensal é uma assinatura com renovação automática de US$ 7,99 por mês. Colorkin Pro anual é uma assinatura com renovação automática de US$ 29,99 por ano, com teste gratuito de 3 dias para novos assinantes. Os dois planos podem ser compartilhados com até 5 familiares pelo Compartilhamento Familiar. Os preços podem variar conforme a região. O pagamento é cobrado na sua Conta Apple ao confirmar a compra ou ao fim do teste gratuito. A assinatura é renovada automaticamente, a menos que a renovação automática seja desativada pelo menos 24 horas antes do fim do período atual; a renovação é cobrada nas 24 horas anteriores a essa data. Você pode gerenciar ou cancelar a qualquer momento nos ajustes da sua Conta Apple.

Um livro de colorir é uma compra única de US$ 4,99 para um livro de até 20 páginas. Três livros de colorir é uma compra única de US$ 9,99 para três livros.

Política de privacidade: https://luongcongtoan.github.io/coloringbook/privacy.html
Termos de uso (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**ja**
```
サブスクリプションについて
Colorkin Pro 月額は月額7.99米ドルの自動更新サブスクリプションです。Colorkin Pro 年額は年額29.99米ドルの自動更新サブスクリプションで、新規登録の方は3日間の無料トライアルがあります。どちらのプランもファミリー共有で最大5人の家族と共有できます。価格は地域によって異なる場合があります。お支払いは購入の確定時、または無料トライアルの終了時にAppleアカウントに請求されます。現在の期間が終わる24時間前までに自動更新をオフにしない限り、サブスクリプションは自動的に更新され、更新料金はその日の24時間前以内に請求されます。Appleアカウントの設定からいつでも管理・解約できます。

ぬりえブック1冊は、最大20ページのブック1冊分の買い切り購入（4.99米ドル）です。ぬりえブック3冊は、ブック3冊分の買い切り購入（9.99米ドル）です。

プライバシーポリシー：https://luongcongtoan.github.io/coloringbook/privacy.html
利用規約（EULA）：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**th**
```
เงื่อนไขการสมัครสมาชิก
Colorkin Pro รายเดือน เป็นการสมัครสมาชิกแบบต่ออายุอัตโนมัติ ราคา 7.99 USD ต่อเดือน Colorkin Pro รายปี เป็นการสมัครสมาชิกแบบต่ออายุอัตโนมัติ ราคา 29.99 USD ต่อปี พร้อมทดลองใช้ฟรี 3 วันสำหรับสมาชิกใหม่ ทั้งสองแพ็กเกจแชร์กับสมาชิกในครอบครัวได้สูงสุด 5 คนผ่านการแชร์กันในครอบครัว ราคาอาจแตกต่างกันในแต่ละประเทศ ระบบจะเรียกเก็บเงินจากบัญชี Apple ของคุณเมื่อยืนยันการซื้อ หรือเมื่อสิ้นสุดช่วงทดลองใช้ฟรี การสมัครสมาชิกจะต่ออายุอัตโนมัติ เว้นแต่จะปิดการต่ออายุอัตโนมัติอย่างน้อย 24 ชั่วโมงก่อนสิ้นสุดรอบปัจจุบัน โดยจะเรียกเก็บค่าต่ออายุภายใน 24 ชั่วโมงก่อนวันดังกล่าว คุณจัดการหรือยกเลิกได้ทุกเมื่อในการตั้งค่าบัญชี Apple

สมุดระบายสี 1 เล่ม เป็นการซื้อครั้งเดียว ราคา 4.99 USD สำหรับสมุด 1 เล่ม สูงสุด 20 หน้า สมุดระบายสี 3 เล่ม เป็นการซื้อครั้งเดียว ราคา 9.99 USD สำหรับสมุด 3 เล่ม

นโยบายความเป็นส่วนตัว: https://luongcongtoan.github.io/coloringbook/privacy.html
เงื่อนไขการใช้งาน (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```
